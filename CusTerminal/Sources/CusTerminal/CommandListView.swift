import SwiftUI
import UniformTypeIdentifiers

/// 카드를 폴더로 이동할 때 쓰는 커스텀 UTType.
/// pane 은 이 타입 등록 안 하므로 무시 → pane 은 텍스트만 실행.
private let commandCardIDType = UTType("com.silverslab.custerminal.commandcard-id") ?? .plainText

/// 폴더 자체를 드래그해 순서 바꿀 때 사용.
private let folderIDType = UTType("com.silverslab.custerminal.folder-id") ?? .plainText

/// 왼쪽 사이드바: 사용법 안내 + 입력창 + 폴더별 카드 리스트 + 하단 설정 진입.
struct CommandListView: View {
  @Bindable var store: CommandStore
  @State private var input: String = ""
  @State private var settingsExpanded: Bool = false

  var body: some View {
    VStack(spacing: 8) {
      // 상단 사용법 안내.
      HStack(spacing: 6) {
        Image(systemName: "hand.point.up.left.fill")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
        Text("카드를 pane 위로 드래그 → 그 pane 에서 실행")
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)

      // 입력창.
      HStack {
        TextField("자주 쓰는 명령 (예: docker ps)", text: $input, onCommit: submit)
          .textFieldStyle(.roundedBorder)
        Button("저장", action: submit)
          .tooltip("입력한 명령을 카드로 저장")
      }
      .padding(.horizontal)

      // 폴더 추가 버튼.
      HStack {
        Spacer()
        Button {
          store.addFolder()
        } label: {
          Label("폴더 추가", systemImage: "folder.badge.plus").font(.caption)
        }
        .buttonStyle(.borderless)
        .tooltip("빈 폴더 만들기. 카드 우클릭 → 폴더로 이동")
      }
      .padding(.horizontal)

      // 카드/폴더 리스트. 상단 (사용법+입력창+폴더추가) 과 하단 (설정) 사이 남는
      // 공간을 다 차지해 스크롤 가능. 폴더가 많아져도 안에서 스크롤.
      ScrollView {
        VStack(spacing: 8) {
          let uncategorized = store.commands(in: nil)
          if store.folders.isEmpty && !uncategorized.isEmpty {
            // 폴더 없이 카드만 있는 경우: 헤더 없이 카드 나열.
            VStack(spacing: 4) {
              ForEach(uncategorized) { cmd in
                CommandCardRow(store: store, command: cmd)
              }
            }
          } else if !store.folders.isEmpty {
            // 폴더가 있으면 미분류 그룹도 항상 표시 (비어있어도).
            UncategorizedGroup(store: store, commands: uncategorized)
          }
          // 각 폴더 자체가 폴더-재배치 drop 을 받음 (위/아래 절반에 따라 앞뒤 삽입).
          ForEach(store.folders) { folder in
            FolderGroup(store: store, folder: folder)
              .transition(.asymmetric(insertion: .opacity, removal: .opacity))
          }
          .animation(.spring(response: 0.35, dampingFraction: 0.78), value: store.folders.map(\.id))
        }
        .padding(.horizontal)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      // 하단 설정.
      VStack(spacing: 6) {
        Divider()
        Button {
          withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            settingsExpanded.toggle()
          }
        } label: {
          HStack(spacing: 6) {
            // 아이콘 하나만 두고 회전 → 펴짐 시 아래 (0°), 접힘 시 위 (180°).
            // 아이콘 자체가 rotation 애니메이션과 함께 부드럽게 돎.
            Image(systemName: "chevron.down")
              .font(.system(size: 10, weight: .semibold))
              .rotationEffect(.degrees(settingsExpanded ? 0 : 180))
              .animation(.spring(response: 0.32, dampingFraction: 0.78), value: settingsExpanded)
            Text("설정")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
            Spacer()
          }
          .contentShape(Rectangle())
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
        }
        .buttonStyle(.plain)

        if settingsExpanded {
          VStack(spacing: 6) {
            ThemePickerButton()
            FontPickerButton()
            BackgroundPickerButton()
            SeparatorPickerButton()
            PetPickerButton()
            WindowOpacityButton()
          }
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func submit() {
    store.add(input)
    input = ""
  }
}

/// FolderGroup 본체에 얹혀 폴더-폴더 드롭.
/// 드래그가 target 위로 오는 순간 실시간으로 store.folders 배열을 재배치 →
/// 다른 폴더들이 밀려나는 프리뷰가 실제로 보임. 드롭 시엔 그 상태 confirm.
private struct FolderDropDelegate: DropDelegate {
  let store: CommandStore
  let target: UUID
  @Binding var position: FolderGroup.FolderInsertPosition

  func dropEntered(info: DropInfo) {
    reorderInPlace(info: info)
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    reorderInPlace(info: info)
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    position = .none
  }

  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [folderIDType])
  }

  func performDrop(info: DropInfo) -> Bool {
    // 이미 실시간으로 재배치됨 → 라인만 지우면 끝.
    position = .none
    return true
  }

  /// 드래그가 target 위에 있는 동안 매 frame:
  ///  - source 폴더의 현재 idx 를 찾고
  ///  - target 위치 위/아래에 따라 원하는 새 idx 계산
  ///  - 다르면 store 에서 즉시 이동 (애니메이션 포함)
  private func reorderInPlace(info: DropInfo) {
    let providers = info.itemProviders(for: [folderIDType])
    guard let provider = providers.first else { return }
    provider.loadDataRepresentation(forTypeIdentifier: folderIDType.identifier) { data, _ in
      guard let data,
            let str = String(data: data, encoding: .utf8),
            let srcID = UUID(uuidString: str)
      else { return }
      DispatchQueue.main.async {
        guard srcID != target,
              let srcIdx = store.folders.firstIndex(where: { $0.id == srcID }),
              let dstIdx = store.folders.firstIndex(where: { $0.id == target })
        else { return }
        let y = info.location.y
        let before = y < 20
        // 이미 원하는 위치면 skip (무한 재배치 방지).
        let desiredIdx = before
          ? (srcIdx < dstIdx ? dstIdx - 1 : dstIdx)
          : (srcIdx < dstIdx ? dstIdx : dstIdx + 1)
        if srcIdx == desiredIdx {
          position = before ? .above : .below
          return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
          store.reorderFolder(source: srcID, target: target, before: before)
        }
        position = before ? .above : .below
      }
    }
  }
}

/// 폴더 사이 얇은 슬롯. 카드 드롭은 무시하고 폴더 재배치만 받음.
/// - targetID 앞에(before=true) 또는 뒤에 삽입.
/// - hover 되면 두꺼운 파란 라인으로 삽입 위치를 표시.
private struct FolderReorderSlot: View {
  @Bindable var store: CommandStore
  let targetID: UUID
  let before: Bool
  @State private var isTarget: Bool = false

  var body: some View {
    ZStack {
      Color.clear
      if isTarget {
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.accentColor)
          .frame(height: 3)
          .shadow(color: Color.accentColor.opacity(0.5), radius: 3)
      }
    }
    .frame(height: 8)
    .contentShape(Rectangle())
    // folderIDType 만 등록 → 카드 드롭은 이 슬롯을 통과.
    .onDrop(of: [folderIDType], isTargeted: $isTarget) { providers in
      guard let provider = providers.first(where: {
        $0.hasItemConformingToTypeIdentifier(folderIDType.identifier)
      }) else { return false }
      provider.loadDataRepresentation(forTypeIdentifier: folderIDType.identifier) { data, _ in
        guard let data,
              let str = String(data: data, encoding: .utf8),
              let srcID = UUID(uuidString: str),
              srcID != targetID
        else { return }
        DispatchQueue.main.async {
          store.reorderFolder(source: srcID, target: targetID, before: before)
        }
      }
      return true
    }
  }
}

/// 카드 ID provider 를 읽어 store 에서 targetFolder 로 이동시킴.
/// - to=nil 이면 미분류로.
@discardableResult
private func handleCardDrop(providers: [NSItemProvider],
                            to folderID: UUID?,
                            store: CommandStore) -> Bool {
  guard let provider = providers.first(where: {
    $0.hasItemConformingToTypeIdentifier(commandCardIDType.identifier)
  }) else { return false }
  provider.loadDataRepresentation(forTypeIdentifier: commandCardIDType.identifier) { data, _ in
    guard let data,
          let str = String(data: data, encoding: .utf8),
          let cardID = UUID(uuidString: str)
    else { return }
    DispatchQueue.main.async {
      store.move(cardID, to: folderID)
    }
  }
  return true
}

/// 폴더 ID provider 를 읽어 target 폴더 앞에 삽입 (순서 변경).
@discardableResult
private func handleFolderReorder(providers: [NSItemProvider],
                                 target: UUID,
                                 store: CommandStore) -> Bool {
  guard let provider = providers.first(where: {
    $0.hasItemConformingToTypeIdentifier(folderIDType.identifier)
  }) else { return false }
  provider.loadDataRepresentation(forTypeIdentifier: folderIDType.identifier) { data, _ in
    guard let data,
          let str = String(data: data, encoding: .utf8),
          let srcID = UUID(uuidString: str),
          srcID != target
    else { return }
    DispatchQueue.main.async {
      store.reorderFolder(source: srcID, target: target, before: true)
    }
  }
  return true
}

/// 폴더 미지정 카드들을 위한 그룹 (헤더 = "미분류").
private struct UncategorizedGroup: View {
  @Bindable var store: CommandStore
  let commands: [SavedCommand]
  @State private var expanded: Bool = true
  @State private var isDropTarget: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Button {
        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 9, weight: .semibold))
          Image(systemName: "tray").font(.system(size: 11))
          Text("미분류")
            .font(.system(size: 11, weight: .semibold))
          Text("(\(commands.count))")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
          Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if expanded {
        VStack(spacing: 4) {
          if commands.isEmpty {
            Text("폴더에서 뺀 카드는 여기로 드롭")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 6)
          } else {
            ForEach(commands) { cmd in
              CommandCardRow(store: store, command: cmd)
            }
          }
        }
      }
    }
    .padding(4)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .stroke(isDropTarget ? Color.accentColor : .clear, lineWidth: 2)
    )
    .onDrop(of: [commandCardIDType], isTargeted: $isDropTarget) { providers in
      handleCardDrop(providers: providers, to: nil, store: store)
    }
  }
}

/// 사용자가 만든 폴더 그룹 (헤더 = 폴더 이름, 접기/펴기 상태는 store 에 저장됨).
private struct FolderGroup: View {
  @Bindable var store: CommandStore
  let folder: CommandFolder
  @State private var editingName: Bool = false
  @State private var nameDraft: String = ""
  @State private var showDeleteConfirm: Bool = false
  @State private var isCardDropTarget: Bool = false
  @State private var folderInsertPosition: FolderInsertPosition = .none

  enum FolderInsertPosition { case none, above, below }

  private var items: [SavedCommand] { store.commands(in: folder.id) }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Button {
          store.toggleCollapsed(folder.id)
        } label: {
          Image(systemName: folder.collapsed ? "chevron.right" : "chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .buttonStyle(.plain)

        Image(systemName: folder.collapsed ? "folder" : "folder.fill")
          .font(.system(size: 11))
          .foregroundStyle(Color.accentColor)

        if editingName {
          TextField("폴더 이름", text: $nameDraft, onCommit: commitRename)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))
            .onExitCommand { editingName = false }
        } else {
          Text(folder.name)
            .font(.system(size: 11, weight: .semibold))
            .onTapGesture(count: 2) {
              nameDraft = folder.name
              editingName = true
            }
            .tooltip("더블클릭해서 이름 변경 · 헤더 가로 영역 아무 곳이나 드래그로 순서 변경")
        }
        Text("(\(items.count))")
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
        Spacer()
        Menu {
          Button("이름 변경") {
            nameDraft = folder.name
            editingName = true
          }
          if items.isEmpty {
            Button("폴더 삭제", role: .destructive) {
              store.removeFolder(folder.id, deleteCommands: false)
            }
          } else {
            Button("폴더 삭제 (카드는 미분류로)") {
              store.removeFolder(folder.id, deleteCommands: false)
            }
            Button("폴더 + 안 카드 모두 삭제…", role: .destructive) {
              showDeleteConfirm = true
            }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 20)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tooltip("폴더 옵션")
      }
      .foregroundStyle(.primary)
      .padding(.vertical, 2)
      // 헤더 가로 영역 전체가 드래그 소스 (이름 텍스트뿐 아니라 빈 공간 포함).
      // contentShape 로 hit 영역 확보. Menu · Button · TextField 위는 각자 이벤트 우선이라 안전.
      .contentShape(Rectangle())
      .onDrag {
        let idData = folder.id.uuidString.data(using: .utf8) ?? Data()
        let p = NSItemProvider()
        p.registerDataRepresentation(forTypeIdentifier: folderIDType.identifier,
                                     visibility: .all) { completion in
          completion(idData, nil)
          return nil
        }
        return p
      }
      .alert("폴더 '\(folder.name)' 삭제", isPresented: $showDeleteConfirm) {
        Button("취소", role: .cancel) {}
        Button("삭제", role: .destructive) {
          store.removeFolder(folder.id, deleteCommands: true)
        }
      } message: {
        Text("이 폴더 안에 있는 명령어 \(items.count) 개도 함께 삭제됩니다.\n되돌릴 수 없습니다.")
      }

      if !folder.collapsed {
        VStack(spacing: 4) {
          ForEach(items) { cmd in
            CommandCardRow(store: store, command: cmd)
          }
          if items.isEmpty {
            Text("빈 폴더")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .padding(.vertical, 4)
          }
        }
      }
    }
    .padding(4)
    .background(
      // 카드 하이라이트는 폴더 드래그 중이 아닐 때만.
      RoundedRectangle(cornerRadius: 6)
        .stroke((isCardDropTarget && folderInsertPosition == .none)
                ? Color.accentColor : .clear, lineWidth: 2)
    )
    // 폴더 본체 위에 폴더 드롭 시 위/아래 위치 라인. padding 밖으로 offset 해 확실히 보이게.
    .overlay(alignment: .top) {
      if folderInsertPosition == .above {
        insertionLine.offset(y: -6).transition(.opacity)
      }
    }
    .overlay(alignment: .bottom) {
      if folderInsertPosition == .below {
        insertionLine.offset(y: 6).transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.12), value: folderInsertPosition)
    // 폴더 재배치 delegate 를 먼저 붙여 우선순위 확보.
    .onDrop(of: [folderIDType], delegate: FolderDropDelegate(
      store: store,
      target: folder.id,
      position: $folderInsertPosition
    ))
    // 카드 드롭: 이 폴더로 이동. 폴더 드래그 중일 땐 위 delegate 가 이미 잡음.
    .onDrop(of: [commandCardIDType], isTargeted: $isCardDropTarget) { providers in
      handleCardDrop(providers: providers, to: folder.id, store: store)
    }
  }

  /// 폴더 사이 삽입 위치 라인 (파란 굵은 라인 + 그림자).
  private var insertionLine: some View {
    RoundedRectangle(cornerRadius: 2)
      .fill(Color.accentColor)
      .frame(height: 4)
      .shadow(color: Color.accentColor.opacity(0.6), radius: 4)
      .padding(.horizontal, 2)
  }

  private func commitRename() {
    let trimmed = nameDraft.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty {
      store.renameFolder(folder.id, to: trimmed)
    }
    editingName = false
  }
}

/// 카드 하나. 우클릭 메뉴로 폴더 이동/삭제.
private struct CommandCardRow: View {
  @Bindable var store: CommandStore
  let command: SavedCommand

  var body: some View {
    HStack {
      Text(command.text)
        .font(.system(.body, design: .monospaced))
        .lineLimit(1)
        .truncationMode(.middle)
        .tooltip(command.text)
      Spacer()
      Button {
        store.remove(command.id)
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .tooltip("이 카드 삭제")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
    .onDrag {
      // Provider 하나에 두 representation 등록:
      //  - plain text (기존): pane 이 감지해 명령 실행
      //  - card ID (신규): 폴더 헤더가 감지해 카드 이동
      let provider = NSItemProvider()
      provider.registerObject(command.text as NSString, visibility: .all)
      let idData = command.id.uuidString.data(using: .utf8) ?? Data()
      provider.registerDataRepresentation(forTypeIdentifier: commandCardIDType.identifier,
                                          visibility: .all) { completion in
        completion(idData, nil)
        return nil
      }
      return provider
    }
    .contextMenu {
      Menu("폴더로 이동") {
        Button("미분류") { store.move(command.id, to: nil) }
        if !store.folders.isEmpty { Divider() }
        ForEach(store.folders) { folder in
          Button(folder.name) { store.move(command.id, to: folder.id) }
        }
        Divider()
        Button("+ 새 폴더 만들기") {
          let f = store.addFolder(name: "새 폴더")
          store.move(command.id, to: f.id)
        }
      }
      Button("삭제", role: .destructive) { store.remove(command.id) }
    }
  }
}
