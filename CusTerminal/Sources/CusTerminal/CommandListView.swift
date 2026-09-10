import SwiftUI
import UniformTypeIdentifiers

/// 카드/폴더 드래그 payload 는 모두 plainText 로 통일. prefix 로 종류 구분.
///  - "CUSTERMINAL_CARD:<uuid>:<text>"   → 카드
///  - "CUSTERMINAL_FOLDER:<uuid>"        → 폴더
/// 커스텀 UTType 은 SwiftUI onDrop 에서 종종 매칭이 어긋나 안 씀.
private let cardPayloadPrefix = "CUSTERMINAL_CARD:"
private let folderPayloadPrefix = "CUSTERMINAL_FOLDER:"

/// 왼쪽 사이드바: 사용법 안내 + 입력창 + 폴더별 카드 리스트 + 하단 설정 진입.
struct CommandListView: View {
  @Bindable var store: CommandStore
  @State private var input: String = ""
  @State private var settingsExpanded: Bool = false
  /// 미분류 그룹 접힘/펴짐 상태.
  @State private var uncategorizedExpanded: Bool = true

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
        TextField("자주 쓰는 명령 (예: docker ps)", text: $input)
          .textFieldStyle(.roundedBorder)
          .onSubmit(submit)
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
            UncategorizedGroup(store: store, commands: uncategorized, expanded: $uncategorizedExpanded)
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
    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    store.add(text)
    input = ""
    // 새 카드는 미분류로 들어가니, 접혀있으면 열어서 방금 추가한 게 보이게.
    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
      uncategorizedExpanded = true
    }
  }
}

/// 카드 드롭과 폴더 재배치 드롭을 하나의 delegate 에서 처리.
/// payload text 의 prefix 로 종류 구분 (커스텀 UTType 안 씀).
private struct FolderCombinedDropDelegate: DropDelegate {
  let store: CommandStore
  let target: UUID
  @Binding var folderPosition: FolderGroup.FolderInsertPosition
  @Binding var cardTargeted: Bool

  func validateDrop(info: DropInfo) -> Bool { true }

  func dropEntered(info: DropInfo) {
    Log.write("FolderCombinedDropDelegate.dropEntered target=\(target.uuidString.prefix(4))")
    // 어떤 payload 인지 아직 모름 → 일단 카드로 가정. 진짜 종류는 performDrop 에서 판정.
    cardTargeted = true
    folderPosition = .none
    // 폴더 여부 판정을 위해 즉시 payload 읽음.
    inspectPayload(info: info) { kind in
      DispatchQueue.main.async {
        switch kind {
        case .folder:
          cardTargeted = false
          folderPosition = info.location.y < 20 ? .above : .below
          reorderInPlace(info: info)
        case .card:
          cardTargeted = true
          folderPosition = .none
        case .unknown:
          cardTargeted = false
          folderPosition = .none
        }
      }
    }
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    // 폴더 hover 위치 실시간 업데이트.
    inspectPayload(info: info) { kind in
      DispatchQueue.main.async {
        switch kind {
        case .folder:
          cardTargeted = false
          folderPosition = info.location.y < 20 ? .above : .below
          reorderInPlace(info: info)
        case .card:
          cardTargeted = true
          folderPosition = .none
        case .unknown:
          break
        }
      }
    }
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    folderPosition = .none
    cardTargeted = false
  }

  func performDrop(info: DropInfo) -> Bool {
    let providers = info.itemProviders(for: [.text, .plainText, .utf8PlainText])
    Log.write("FolderCombinedDropDelegate.performDrop target=\(target.uuidString.prefix(4)) providers=\(providers.count)")
    guard let provider = providers.first else {
      folderPosition = .none
      cardTargeted = false
      return false
    }
    _ = provider.loadObject(ofClass: NSString.self) { obj, err in
      if let err { Log.write("  performDrop loadObject err: \(err)") }
      guard let text = obj as? String else {
        Log.write("  performDrop no string")
        DispatchQueue.main.async {
          self.folderPosition = .none
          self.cardTargeted = false
        }
        return
      }
      Log.write("  performDrop text=\(text.prefix(60))")
      DispatchQueue.main.async {
        if text.hasPrefix(folderPayloadPrefix) {
          // 폴더는 이미 실시간 재배치됨 → 상태만 리셋.
          self.folderPosition = .none
          self.cardTargeted = false
        } else if text.hasPrefix(cardPayloadPrefix) {
          let rest = String(text.dropFirst(cardPayloadPrefix.count))
          let parts = rest.split(separator: ":", maxSplits: 1)
          if let idPart = parts.first, let cardID = UUID(uuidString: String(idPart)) {
            Log.write("  performDrop card cardID=\(cardID.uuidString.prefix(4)) → move to \(self.target.uuidString.prefix(4))")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
              self.store.move(cardID, to: self.target)
            }
          }
          self.cardTargeted = false
          self.folderPosition = .none
        }
      }
    }
    return true
  }

  // MARK: - payload 종류 판정

  private enum PayloadKind { case card, folder, unknown }

  private func inspectPayload(info: DropInfo, completion: @escaping (PayloadKind) -> Void) {
    let providers = info.itemProviders(for: [.text, .plainText, .utf8PlainText])
    guard let provider = providers.first else {
      completion(.unknown)
      return
    }
    _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
      guard let text = obj as? String else {
        completion(.unknown)
        return
      }
      if text.hasPrefix(folderPayloadPrefix) { completion(.folder) }
      else if text.hasPrefix(cardPayloadPrefix) { completion(.card) }
      else { completion(.unknown) }
    }
  }

  private func reorderInPlace(info: DropInfo) {
    let providers = info.itemProviders(for: [.text, .plainText, .utf8PlainText])
    guard let provider = providers.first else { return }
    _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
      guard let text = obj as? String,
            text.hasPrefix(folderPayloadPrefix)
      else { return }
      let idStr = String(text.dropFirst(folderPayloadPrefix.count))
      guard let srcID = UUID(uuidString: idStr) else { return }
      DispatchQueue.main.async {
        guard srcID != target,
              let srcIdx = store.folders.firstIndex(where: { $0.id == srcID }),
              let dstIdx = store.folders.firstIndex(where: { $0.id == target })
        else { return }
        let y = info.location.y
        let before = y < 20
        let desiredIdx = before
          ? (srcIdx < dstIdx ? dstIdx - 1 : dstIdx)
          : (srcIdx < dstIdx ? dstIdx : dstIdx + 1)
        if srcIdx == desiredIdx {
          folderPosition = before ? .above : .below
          return
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
          store.reorderFolder(source: srcID, target: target, before: before)
        }
        folderPosition = before ? .above : .below
      }
    }
  }
}

/// plain text provider 에서 "CUSTERMINAL_CARD:<uuid>:<text>" 형식 파싱해 카드 이동.
/// - to=nil 이면 미분류로.
@discardableResult
private func handleCardDrop(providers: [NSItemProvider],
                            to folderID: UUID?,
                            store: CommandStore) -> Bool {
  Log.write("handleCardDrop providers=\(providers.count) to=\(folderID?.uuidString.prefix(4) ?? "미분류")")
  guard let provider = providers.first else {
    Log.write("  no provider → abort")
    return false
  }
  Log.write("  provider types=\(provider.registeredTypeIdentifiers)")
  _ = provider.loadObject(ofClass: NSString.self) { obj, err in
    if let err { Log.write("  loadObject error: \(err)") }
    guard let text = obj as? String else {
      Log.write("  no string from provider")
      return
    }
    Log.write("  text prefix=\(text.prefix(40))")
    let prefix = "CUSTERMINAL_CARD:"
    guard text.hasPrefix(prefix) else {
      Log.write("  no CUSTERMINAL_CARD prefix → not a card drop")
      return
    }
    let rest = String(text.dropFirst(prefix.count))
    let parts = rest.split(separator: ":", maxSplits: 1)
    guard let idPart = parts.first, let cardID = UUID(uuidString: String(idPart)) else {
      Log.write("  failed to parse card UUID from '\(rest.prefix(40))'")
      return
    }
    Log.write("  parsed cardID=\(cardID.uuidString.prefix(4)) → move")
    DispatchQueue.main.async {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
        store.move(cardID, to: folderID)
      }
    }
  }
  return true
}


/// 폴더 미지정 카드들을 위한 그룹 (헤더 = "미분류").
private struct UncategorizedGroup: View {
  @Bindable var store: CommandStore
  let commands: [SavedCommand]
  @Binding var expanded: Bool
  @State private var isDropTarget: Bool = false

  /// 새 카드가 위에 오도록 뒤집어 표시. 저장된 배열 순서 자체는 안 건드림.
  private var displayCommands: [SavedCommand] { commands.reversed() }

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
            ForEach(displayCommands) { cmd in
              CommandCardRow(store: store, command: cmd)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
          }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: commands.map(\.id))
      }
    }
    .padding(4)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .stroke(isDropTarget ? Color.accentColor : .clear, lineWidth: 2)
    )
    .onDrop(of: [.text, .plainText, .utf8PlainText], isTargeted: $isDropTarget) { providers in
      Log.write("UncategorizedGroup.onDrop providers=\(providers.count)")
      return handleCardDrop(providers: providers, to: nil, store: store)
    }
    .onChange(of: store.commands.map { "\($0.id)|\($0.folderID?.uuidString ?? "")" }) { _, _ in
      isDropTarget = false
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
      .contentShape(Rectangle())
      .onDrag {
        // 폴더 드래그도 plainText payload 로 통일. prefix 로 카드와 구분.
        let payload = "\(folderPayloadPrefix)\(folder.id.uuidString)"
        return NSItemProvider(object: payload as NSString)
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
    // store 변화 (카드 이동 · 폴더 이동 · folderID 변경 모두) 감지 → 잔여 강제 리셋.
    .onChange(of: store.commands.map { "\($0.id)|\($0.folderID?.uuidString ?? "")" }) { _, _ in
      folderInsertPosition = .none
      isCardDropTarget = false
    }
    .onChange(of: store.folders.map(\.id)) { _, _ in
      folderInsertPosition = .none
      isCardDropTarget = false
    }
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
    // 카드/폴더 드롭을 하나의 delegate 로 통합. payload 종류에 따라 분기.
    // (두 onDrop 을 겹쳐 놓으면 앞의 것이 뒤의 것을 삼켜 다른 폴더로 카드 이동이 안 되는 문제)
    .onDrop(of: [.text, .plainText, .utf8PlainText],
            delegate: FolderCombinedDropDelegate(
              store: store,
              target: folder.id,
              folderPosition: $folderInsertPosition,
              cardTargeted: $isCardDropTarget
            ))
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
      // 하나의 plain text provider 로 통합.
      // 형식: "CUSTERMINAL_CARD:<uuid>:<command_text>"
      //  - 폴더 drop: prefix 매칭 → uuid 파싱해 이동
      //  - pane drop: prefix 있으면 stripping 후 실행 (or 그대로 실행 후 실패도 OK)
      // 커스텀 UTType 은 SwiftUI onDrop 이 잘 못 잡는 경우가 있어 표준 plainText 만 사용.
      let payload = "CUSTERMINAL_CARD:\(command.id.uuidString):\(command.text)"
      return NSItemProvider(object: payload as NSString)
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
