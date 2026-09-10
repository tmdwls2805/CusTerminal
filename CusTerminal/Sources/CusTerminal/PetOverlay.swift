import SwiftUI
import AppKit

/// pane 컨테이너 위에 얹히는 펫 오버레이.
/// 창 하단을 따라 천천히 걸어다닌다.
struct PetOverlay: View {
  @Environment(PetStore.self) private var store
  @State private var pets: [Pet] = []
  @State private var timer: Timer?
  @State private var containerSize: CGSize = .zero

  private let stepInterval: TimeInterval = 0.15  // 프레임/스텝 tick
  private let scale: CGFloat = 3.0
  private let spriteSize: CGFloat = 16 * 3      // = 48

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        Color.clear
        ForEach(pets) { pet in
          PetImageView(species: pet.species, frame: pet.animFrame, facingRight: pet.facingRight, scale: scale, spriteSize: spriteSize)
            .position(x: pet.x, y: geo.size.height - spriteSize / 2 - 2)
            .allowsHitTesting(false)
        }
      }
      .onAppear {
        containerSize = geo.size
        syncPets()
        startTimer()
      }
      .onChange(of: geo.size) { _, new in
        containerSize = new
        syncPets()  // 창 사이즈 바뀌면 벽 밖 나간 펫 안쪽으로.
      }
      .onDisappear {
        timer?.invalidate()
        timer = nil
      }
      .onChange(of: store.counts) { _, _ in
        syncPets()
      }
    }
    .allowsHitTesting(false)
  }

  /// store 마릿수 대로 pets 배열 조정.
  private func syncPets() {
    var next: [Pet] = []
    for species in PetSpecies.allCases {
      let target = store.count(for: species)
      let existing = pets.filter { $0.species == species }
      // 유지: min(existing, target)
      let keep = Array(existing.prefix(target))
      next.append(contentsOf: keep)
      // 부족분 추가.
      let missing = target - keep.count
      for _ in 0..<max(0, missing) {
        next.append(Pet(species: species, x: CGFloat.random(in: 20...(max(21, containerSize.width - 20)))))
      }
    }
    pets = next
  }

  private func startTimer() {
    timer?.invalidate()
    let t = Timer(timeInterval: stepInterval, repeats: true) { _ in
      DispatchQueue.main.async { step() }
    }
    RunLoop.main.add(t, forMode: .common)
    timer = t
  }

  private func step() {
    guard !pets.isEmpty else { return }
    let w = containerSize.width
    var updated: [Pet] = []
    for var p in pets {
      p.x += p.facingRight ? p.speed : -p.speed
      // 벽 만나면 반전.
      let margin: CGFloat = spriteSize / 2 + 4
      if p.x <= margin { p.x = margin; p.facingRight = true }
      if p.x >= w - margin { p.x = w - margin; p.facingRight = false }
      // 프레임 토글.
      p.tick += 1
      if p.tick % 2 == 0 { p.animFrame = (p.animFrame + 1) % 2 }
      // 랜덤 방향 전환 (아주 낮은 확률).
      if Int.random(in: 0..<200) < 2 { p.facingRight.toggle() }
      updated.append(p)
    }
    pets = updated
  }
}

/// 펫 이미지 렌더. GIF 프레임 있으면 우선 사용, 없으면 코드 스프라이트 fallback.
struct PetImageView: View {
  let species: PetSpecies
  let frame: Int
  let facingRight: Bool
  let scale: CGFloat
  let spriteSize: CGFloat

  private static var gifCache: [PetSpecies: [NSImage]] = [:]

  private var gifFrames: [NSImage]? {
    if let cached = PetImageView.gifCache[species] { return cached.isEmpty ? nil : cached }
    let loaded = PetAssetLoader.gifFrames(for: species) ?? []
    PetImageView.gifCache[species] = loaded
    return loaded.isEmpty ? nil : loaded
  }

  var body: some View {
    if let frames = gifFrames {
      // GIF 프레임 우선 사용.
      let img = frames[frame % frames.count]
      Image(nsImage: img)
        .interpolation(.none)
        .resizable()
        .frame(width: spriteSize, height: spriteSize)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
    } else {
      // fallback: 코드 스프라이트.
      Image(nsImage: PetSpriteCatalog.sprite(for: species)
              .image(frame: frame, facingRight: facingRight, scale: scale))
    }
  }
}

/// 개별 펫 상태.
struct Pet: Identifiable, Equatable {
  let id = UUID()
  let species: PetSpecies
  var x: CGFloat
  var facingRight: Bool = Bool.random()
  var animFrame: Int = 0
  var tick: Int = 0
  var speed: CGFloat = CGFloat.random(in: 0.8...1.6)
}
