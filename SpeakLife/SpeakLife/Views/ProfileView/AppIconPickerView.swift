//
//  AppIconPickerView.swift
//  SpeakLife
//
//  Lets users choose between the default app icon and the alternate
//  painted-scene icons. Alternate icon names must match the appiconset
//  names listed in ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES.
//

import SwiftUI
import FirebaseAnalytics

struct AppIconOption: Identifiable {
    /// Name passed to setAlternateIconName; nil means the primary icon.
    let iconName: String?
    /// Imageset used to preview the icon inside the app (appiconsets
    /// aren't loadable via UIImage(named:)).
    let previewImageName: String
    let title: String
    let subtitle: String

    var id: String { iconName ?? "default" }

    static let all: [AppIconOption] = [
        AppIconOption(
            iconName: nil,
            previewImageName: "appIconDisplay",
            title: "Classic",
            subtitle: "The original SpeakLife icon"
        ),
        AppIconOption(
            iconName: "AppIcon-Night",
            previewImageName: "appIconNightDisplay",
            title: "Starry Night",
            subtitle: "His promises shine in the night sky"
        ),
        AppIconOption(
            iconName: "AppIcon-Sunrise",
            previewImageName: "appIconSunriseDisplay",
            title: "Golden Sunrise",
            subtitle: "New mercies every morning"
        )
    ]
}

struct AppIconPickerView: View {

    @State private var selectedIconName: String? = UIApplication.shared.alternateIconName
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()

            List {
                Section(footer: Text("Your new icon shows up on the Home Screen right away.")) {
                    ForEach(AppIconOption.all) { option in
                        iconRow(option)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't Change Icon", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
        .onAppear {
            Analytics.logEvent("app_icon_picker_opened", parameters: nil)
        }
    }

    private func iconRow(_ option: AppIconOption) -> some View {
        Button {
            select(option)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(option.previewImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.white)
                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                if selectedIconName == option.iconName {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Constants.DAMidBlue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func select(_ option: AppIconOption) {
        guard option.iconName != selectedIconName else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = "Changing the app icon isn't supported on this device."
            showError = true
            return
        }

        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else {
                    selectedIconName = option.iconName
                    Analytics.logEvent("app_icon_changed", parameters: [
                        "icon": option.id
                    ])
                }
            }
        }
    }
}
