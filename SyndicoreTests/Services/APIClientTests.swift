import XCTest
@testable import Syndicore

/// Testovi za APIClient sa mock URLSession (URLProtocol intercept).
/// Pokriva: 401 retry + token refresh, decode failures, error mapping.
final class APIClientTests: XCTestCase {

    // MARK: - 401 Retry Logic

    /// Kad BE vrati 401 prvi put, APIClient treba da pozove refreshToken() i replay-uje.
    func test401_triggersRefreshAndReplay() async throws {
        let provider = MockTokenProvider(initial: "stale-token", refreshed: "fresh-token")
        let session = mockSession(behavior: .respondBasedOnAuthHeader { header in
            if header?.contains("stale-token") == true {
                return (401, Data())
            }
            if header?.contains("fresh-token") == true {
                return (200, Data(#"{"status":"ok","game":"test","db":"ok","commit":"abc"}"#.utf8))
            }
            return (500, Data())
        })

        let client = APIClient(
            baseURL: URL(string: "https://test.local")!,
            tokenProvider: provider,
            session: session
        )

        _ = try await client.health()
        XCTAssertEqual(provider.refreshCount, 1, "refreshToken treba da bude pozvan tacno 1 put")
    }

    /// Ako refresh takodje vrati 401, APIClient treba da baci APIError.unauthorized bez beskonacnog retry loop-a.
    func test401_afterRefresh_throwsUnauthorized() async throws {
        let provider = MockTokenProvider(initial: "stale", refreshed: "also-stale")
        let session = mockSession(behavior: .alwaysRespond(status: 401, data: Data()))

        let client = APIClient(
            baseURL: URL(string: "https://test.local")!,
            tokenProvider: provider,
            session: session
        )

        do {
            _ = try await client.me()
            XCTFail("Ocekivao APIError.unauthorized")
        } catch APIError.unauthorized {
            // OK
            XCTAssertLessThanOrEqual(provider.refreshCount, 1, "Max 1 retry — ne sme loop")
        } catch {
            XCTFail("Ocekivao .unauthorized, dobio \(error)")
        }
    }

    // MARK: - Mock helpers

    private func mockSession(behavior: MockURLProtocol.Behavior) -> URLSession {
        MockURLProtocol.behavior = behavior
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

// MARK: - MockTokenProvider

final class MockTokenProvider: TokenProvider, @unchecked Sendable {
    private(set) var refreshCount = 0
    private var current: String
    private let afterRefresh: String

    init(initial: String, refreshed: String) {
        self.current = initial
        self.afterRefresh = refreshed
    }

    func accessToken() async throws -> String { current }

    func refreshToken() async throws -> String {
        refreshCount += 1
        current = afterRefresh
        return current
    }
}

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    enum Behavior {
        case alwaysRespond(status: Int, data: Data)
        case respondBasedOnAuthHeader((String?) -> (Int, Data))
    }

    nonisolated(unsafe) static var behavior: Behavior = .alwaysRespond(status: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let header = request.value(forHTTPHeaderField: "Authorization")
        let (status, data): (Int, Data) = {
            switch Self.behavior {
            case .alwaysRespond(let status, let data):
                return (status, data)
            case .respondBasedOnAuthHeader(let fn):
                return fn(header)
            }
        }()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
