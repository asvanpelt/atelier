import SwiftUI
import AppKit

struct ProfileSwitcher: View {
    @Bindable var store: ProfileStore

    @State private var showNewProfile = false
    @State private var renameTarget: Profile?
    @State private var deleteTarget: Profile?
    @State private var newName: String = ""
    @State private var newIcon: String = "photo.stack"

    var body: some View {
        Menu {
            ForEach(store.profiles) { profile in
                Button {
                    select(profile)
                } label: {
                    Label(profile.name, systemImage: profile.icon)
                    if profile.id == store.activeProfileID {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            Button {
                newName = ""
                newIcon = "photo.stack"
                showNewProfile = true
            } label: {
                Label("Nuevo perfil…", systemImage: "plus.circle")
            }

            Menu {
                ForEach(store.profiles) { profile in
                    Button {
                        renameTarget = profile
                        newName = profile.name
                        newIcon = profile.icon
                    } label: {
                        Label(profile.name, systemImage: profile.icon)
                    }
                }
            } label: {
                Label("Renombrar…", systemImage: "pencil")
            }

            if store.profiles.count > 1 {
                Menu {
                    ForEach(store.profiles) { profile in
                        Button(role: .destructive) {
                            deleteTarget = profile
                        } label: {
                            Label(profile.name, systemImage: profile.icon)
                        }
                    }
                } label: {
                    Label("Eliminar…", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: store.activeProfile.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(store.activeProfile.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .sheet(isPresented: $showNewProfile) {
            profileSheet(
                title: "Nuevo perfil",
                confirmLabel: "Crear",
                onConfirm: {
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let created = store.create(name: trimmed, icon: newIcon)
                    showNewProfile = false
                    select(created)
                },
                onCancel: { showNewProfile = false }
            )
        }
        .sheet(item: $renameTarget) { target in
            profileSheet(
                title: "Renombrar perfil",
                confirmLabel: "Guardar",
                onConfirm: {
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.rename(target.id, to: trimmed)
                    store.updateIcon(target.id, to: newIcon)
                    renameTarget = nil
                },
                onCancel: { renameTarget = nil }
            )
        }
        .alert(
            "¿Eliminar perfil “\(deleteTarget?.name ?? "")”?",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { target in
            Button("Eliminar", role: .destructive) {
                do {
                    try store.delete(target.id)
                    if target.id == store.activeProfileID {
                        relaunchApp()
                    }
                } catch {
                    Logger.general.error("Error eliminando perfil: \(error.localizedDescription)")
                }
                deleteTarget = nil
            }
            Button("Cancelar", role: .cancel) { deleteTarget = nil }
        } message: { _ in
            Text("Se eliminarán la base de datos, los tags, las miniaturas y el índice de este perfil. Tus archivos originales no se tocarán.")
        }
    }

    @ViewBuilder
    private func profileSheet(
        title: String,
        confirmLabel: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)

            TextField("Nombre", text: $newName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icono").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34)), count: 8), spacing: 8) {
                    ForEach(Self.iconChoices, id: \.self) { name in
                        Button {
                            newIcon = name
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 16))
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(newIcon == name ? Color.accentColor.opacity(0.25) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(newIcon == name ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancelar", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func select(_ profile: Profile) {
        guard profile.id != store.activeProfileID else { return }
        store.setActive(profile.id)
        relaunchApp()
    }

    private func relaunchApp() {
        guard let executableURL = Bundle.main.executableURL else {
            Logger.general.error("No se encontró el ejecutable del bundle")
            NSApp.terminate(nil)
            return
        }

        let task = Process()
        task.executableURL = executableURL
        task.standardInput = nil
        task.standardOutput = nil
        task.standardError = nil

        do {
            try task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
        } catch {
            Logger.general.error("Error al relanzar: \(error.localizedDescription)")
        }
    }

    private static let iconChoices = [
        "photo.stack", "photo.on.rectangle", "camera", "person.crop.rectangle",
        "briefcase", "house", "heart", "star",
        "tag", "folder", "tray.full", "square.stack.3d.up",
        "sparkles", "wand.and.stars", "paintpalette", "gamecontroller"
    ]
}
