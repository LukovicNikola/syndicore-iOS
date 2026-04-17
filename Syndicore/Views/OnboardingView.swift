import SwiftUI

struct OnboardingView: View {
    @Environment(GameState.self) private var gameState

    @State private var username = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        let pattern = /^[a-zA-Z0-9_-]{3,20}$/
        return username.wholeMatch(of: pattern) != nil
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("SYNDICORE")
                .font(.largeTitle.bold())
                .tracking(4)

            Text("Choose your identity")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isSubmitting)

                Text("3-20 characters. Letters, numbers, _ and - only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Enter the Grid")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || isSubmitting)
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .preferredColorScheme(.dark)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        do {
            let response = try await gameState.api.onboard(username: username)
            await gameState.didOnboard(player: response.player)
        } catch let error as APIError {
            switch error {
            case .conflict(let err):
                if err.error == "already_onboarded" {
                    await gameState.bootstrap()
                    return
                }
                errorMessage = err.error
            case .badRequest(let err): errorMessage = err.error
            default: errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
