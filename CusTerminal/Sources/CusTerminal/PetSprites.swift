import AppKit

/// GIF asset 로더 (지금은 사용 안 함 — 항상 nil 반환해서 코드 스프라이트 fallback).
/// 파일 자체는 Assets/pets/ 아래 그대로 보관.
enum PetAssetLoader {
  static func gifFrames(for species: PetSpecies) -> [NSImage]? { nil }
}

/// 픽셀 아트 스프라이트 데이터.
/// 16x16 격자 · 각 셀은 팔레트 인덱스 문자. `.` = 투명.
enum PetSpecies: String, CaseIterable, Codable, Identifiable {
  case cat, dog, turtle, duck
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .cat: return "고양이"
    case .dog: return "강아지"
    case .turtle: return "거북이"
    case .duck: return "오리"
    }
  }
  var emoji: String {
    switch self {
    case .cat: return "🐱"
    case .dog: return "🐕"
    case .turtle: return "🐢"
    case .duck: return "🦆"
    }
  }
}

/// 한 스프라이트의 걷기 프레임 (2개) + 팔레트.
struct PetSprite {
  let width: Int = 16
  let height: Int = 16
  let palette: [Character: NSColor]
  let frames: [[String]]  // frames[frameIndex] = 16개 행 배열, 각 행은 길이 16 문자열

  /// 특정 프레임을 NSImage 로 렌더 (facingRight = false 면 좌우 반전).
  func image(frame: Int, facingRight: Bool, scale: CGFloat = 3.0) -> NSImage {
    let f = frames[frame % frames.count]
    let px = Int(scale)
    let w = width * px
    let h = height * px
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus()
    defer { img.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }
    ctx.interpolationQuality = .none
    for y in 0..<height {
      let row = f[y]
      for x in 0..<width {
        let idx = row.index(row.startIndex, offsetBy: x)
        let ch = row[idx]
        guard ch != ".", let color = palette[ch] else { continue }
        // facingRight=false 면 x 좌우 반전.
        let px_x = facingRight ? x : (width - 1 - x)
        let rect = CGRect(x: px_x * px, y: (height - 1 - y) * px, width: px, height: px)
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
      }
    }
    return img
  }
}

/// 각 종별 스프라이트 정의.
enum PetSpriteCatalog {
  static func sprite(for species: PetSpecies) -> PetSprite {
    switch species {
    case .cat: return cat
    case .dog: return dog
    case .turtle: return turtle
    case .duck: return duck
    }
  }

  // MARK: - Cat (오렌지 태비, 옆모습 · 오른쪽 바라봄)
  // 왼쪽 = 엉덩이/꼬리, 오른쪽 = 얼굴/귀. facingRight=false 시 자동 좌우 반전.
  static let cat = PetSprite(
    palette: [
      "o": NSColor(srgbRed: 0.95, green: 0.60, blue: 0.25, alpha: 1),  // 몸통 오렌지
      "d": NSColor(srgbRed: 0.55, green: 0.30, blue: 0.10, alpha: 1),  // 태비 무늬
      "p": NSColor(srgbRed: 1.00, green: 0.70, blue: 0.75, alpha: 1),  // 코/귀 안쪽 핑크
      "k": NSColor.black,                                              // 눈/코/윤곽
      "w": NSColor.white,                                              // 눈 하이라이트
    ],
    frames: [
      // Frame 0: 앞다리 붙음 · 뒷다리 벌림
      [
        "................",
        "................",
        "..............o.",  // 귀 tip (오른쪽 = 얼굴 방향)
        "............oopo",  // 귀 안쪽 핑크
        "..........oooopo",
        ".........oooooko",  // 눈
        ".ooo....oooookpo",  // 꼬리 시작 + 얼굴 (코 핑크)
        "oooooooooooookoo",
        "ooddoooooddoooo.",  // 몸통 태비 무늬
        "oooooooooooooo..",
        "oooooooooooooo..",
        ".oo..oo..oo..oo.",  // 앞뒤 다리 (앞: 오른쪽 두 다리, 뒤: 왼쪽 두 다리)
        ".oo..oo..oo..oo.",
        ".kk..kk..kk..kk.",  // 발끝
        "................",
        "................",
      ],
      // Frame 1: 다리 위치 반대로 (걷기 애니)
      [
        "................",
        "................",
        "..............o.",
        "............oopo",
        "..........oooopo",
        ".........oooooko",
        ".ooo....oooookpo",
        "oooooooooooookoo",
        "ooddoooooddoooo.",
        "oooooooooooooo..",
        "oooooooooooooo..",
        "..oo..oo..oo..oo",
        "..oo..oo..oo..oo",
        "..kk..kk..kk..kk",
        "................",
        "................",
      ],
    ]
  )

  // MARK: - Dog (갈색 강아지)
  static let dog = PetSprite(
    palette: [
      "b": NSColor(srgbRed: 0.60, green: 0.40, blue: 0.20, alpha: 1),
      "d": NSColor(srgbRed: 0.35, green: 0.20, blue: 0.10, alpha: 1),
      "w": NSColor.white,
      "k": NSColor.black,
      "p": NSColor(srgbRed: 1.00, green: 0.70, blue: 0.70, alpha: 1),
    ],
    frames: [
      [
        "................",
        "..dd............",
        ".bbbdd..........",
        ".bwbbb..........",
        "bbkbbbbbbbbbbbb.",
        "bbpbbbbbbbbbbbbb",
        ".bbbbbbbbbbbbbbb",
        ".bbbbbbbbbbbbbb.",
        ".bbbbbbbbbbbbbb.",
        "..bb..bb..bb..bb",
        "..bb..bb..bb..bb",
        "................",
        "................",
        "................",
        "................",
        "................",
      ],
      [
        "................",
        "..dd............",
        ".bbbdd..........",
        ".bwbbb..........",
        "bbkbbbbbbbbbbbb.",
        "bbpbbbbbbbbbbbbb",
        ".bbbbbbbbbbbbbbb",
        ".bbbbbbbbbbbbbb.",
        ".bbbbbbbbbbbbbb.",
        ".bb..bb..bb..bb.",
        ".bb..bb..bb..bb.",
        "................",
        "................",
        "................",
        "................",
        "................",
      ],
    ]
  )

  // MARK: - Turtle (옆모습 · 오른쪽 바라봄)
  // 왼쪽 = 꼬리, 오른쪽 = 머리. 등껍질 반원 + 네 다리 + 목/머리.
  static let turtle = PetSprite(
    palette: [
      "g": NSColor(srgbRed: 0.30, green: 0.65, blue: 0.35, alpha: 1),  // 등껍질 밝은 초록
      "d": NSColor(srgbRed: 0.18, green: 0.45, blue: 0.22, alpha: 1),  // 등껍질 무늬 / 윤곽
      "y": NSColor(srgbRed: 0.85, green: 0.75, blue: 0.35, alpha: 1),  // 등껍질 무늬 밝은 노랑
      "s": NSColor(srgbRed: 0.55, green: 0.75, blue: 0.45, alpha: 1),  // 피부 (다리/목)
      "k": NSColor.black,                                              // 눈
      "w": NSColor.white,                                              // 눈 하이라이트
    ],
    frames: [
      // Frame 0
      [
        "................",
        "................",
        "................",
        "....dddddddd....",
        "...dggydggydgd..",
        "..dgygggygygggd.",
        "..dggydgggygdgd.",
        ".ddggygggygyggdd",
        "sddggygygggygdds",
        ".ssdddddddddss.k",
        "..ss......ss.wkw",
        "..ss......ss..k.",
        "................",
        "................",
        "................",
        "................",
      ],
      // Frame 1: 다리 반대편
      [
        "................",
        "................",
        "................",
        "....dddddddd....",
        "...dggydggydgd..",
        "..dgygggygygggd.",
        "..dggydgggygdgd.",
        ".ddggygggygyggdd",
        "sddggygygggygdds",
        ".ssdddddddddss.k",
        "...ss....ss..wkw",
        "...ss....ss...k.",
        "................",
        "................",
        "................",
        "................",
      ],
    ]
  )

  // MARK: - Duck (노란 오리)
  static let duck = PetSprite(
    palette: [
      "y": NSColor(srgbRed: 1.00, green: 0.85, blue: 0.20, alpha: 1),
      "d": NSColor(srgbRed: 0.85, green: 0.65, blue: 0.10, alpha: 1),
      "o": NSColor(srgbRed: 1.00, green: 0.55, blue: 0.10, alpha: 1),  // 부리
      "k": NSColor.black,
      "w": NSColor.white,
    ],
    frames: [
      [
        "................",
        "......yyyy......",
        ".....yyyyyy.....",
        ".....ywkyyy.....",
        "...oooyyyyy.....",
        "...ooyyyyyyy....",
        "....yyyyyyyyy...",
        "....yyyyyyyyy...",
        "....yyyyyyyyy...",
        "....dyyyyyyyd...",
        ".....y......y...",
        ".....y......y...",
        "................",
        "................",
        "................",
        "................",
      ],
      [
        "................",
        "......yyyy......",
        ".....yyyyyy.....",
        ".....ywkyyy.....",
        "...oooyyyyy.....",
        "...ooyyyyyyy....",
        "....yyyyyyyyy...",
        "....yyyyyyyyy...",
        "....yyyyyyyyy...",
        "....dyyyyyyyd...",
        "......y......y..",
        "......y......y..",
        "................",
        "................",
        "................",
        "................",
      ],
    ]
  )
}
