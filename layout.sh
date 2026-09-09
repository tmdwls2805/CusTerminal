# iterm-layout — iTerm2 자동 분할
# 사용:
#   layout            → GUI 프롬프트 (한 창에 세로/가로 인풋 2개)
#   layout 4 3        → 왼쪽 4행 · 오른쪽 3행 (새 창)
layout() {
  local left="$1"
  local right="$2"

  if [ -z "$left" ] || [ -z "$right" ]; then
    # 한 창에 두 개의 텍스트 필드 (세로/가로) 를 표시하기 위해 JXA 사용.
    # 결과는 "L,R" 형태 or "CANCEL".
    local reply
    reply=$(osascript -l JavaScript <<'END'
ObjC.import('AppKit');

// osascript 를 포어그라운드 앱으로 만들어 modal 창이 다른 창 뒤로 숨지 않게 한다.
$.NSApplication.sharedApplication.setActivationPolicy(0);
$.NSApplication.sharedApplication.activateIgnoringOtherApps(true);

function makeField(placeholder, y) {
  const f = $.NSTextField.alloc.initWithFrame($.NSMakeRect(90, y, 120, 24));
  f.placeholderString = placeholder;
  f.stringValue = "";
  return f;
}

function makeLabel(text, y) {
  const l = $.NSTextField.alloc.initWithFrame($.NSMakeRect(0, y + 3, 85, 20));
  l.stringValue = text;
  l.editable = false;
  l.bordered = false;
  l.drawsBackground = false;
  l.alignment = $.NSTextAlignmentRight;
  return l;
}

const app = Application.currentApplication();
app.includeStandardAdditions = true;

const view = $.NSView.alloc.initWithFrame($.NSMakeRect(0, 0, 220, 68));
const leftField = makeField("예: 4", 36);
const rightField = makeField("예: 3", 4);
view.addSubview(makeLabel("왼쪽 세로 :", 36));
view.addSubview(leftField);
view.addSubview(makeLabel("오른쪽 세로 :", 4));
view.addSubview(rightField);

const alert = $.NSAlert.alloc.init;
alert.messageText = "iterm-layout";
alert.informativeText = "왼쪽 열과 오른쪽 열의 세로 분할 수를 입력하세요.";
alert.accessoryView = view;
alert.addButtonWithTitle("생성");
alert.addButtonWithTitle("취소");

const res = alert.runModal;
if (res != 1000) { "CANCEL" }
else {
  const l = ObjC.unwrap(leftField.stringValue);
  const r = ObjC.unwrap(rightField.stringValue);
  l + "," + r;
}
END
)
    [ "$reply" = "CANCEL" ] && return 0
    left="${reply%,*}"
    right="${reply#*,}"
    left=$(printf '%s' "$left" | tr -d '[:space:]')
    right=$(printf '%s' "$right" | tr -d '[:space:]')
    case "$left$right" in
      ''|*[!0-9]*|0*|*0)
        osascript -e 'display dialog "1 이상의 숫자만 입력하세요." buttons {"확인"} default button "확인" with title "iterm-layout"' >/dev/null 2>&1
        return 1
        ;;
    esac
  fi

  case "$left$right" in
    ''|*[!0-9]*) echo "layout: 숫자 두 개가 필요합니다 (예: layout 4 3)"; return 1 ;;
  esac

  # CUSTERMINAL_APP 환경변수(.app 번들 경로) 지정 시 자체 앱으로 띄우고 종료.
  # 예: export CUSTERMINAL_APP="$HOME/Desktop/everyoung-code/iterm-layout/CusTerminal/.build/release/CusTerminal.app"
  # 이전 이름(MYTERM_APP)도 하위 호환으로 인식.
  APP_PATH="${CUSTERMINAL_APP:-$MYTERM_APP}"
  if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    open -n "$APP_PATH" --args --layout "${left},${right}"
    return 0
  fi
  # Legacy: raw binary (창이 안 뜨는 경우가 있어 .app 권장).
  BIN_PATH="${CUSTERMINAL_BIN:-$MYTERM_BIN}"
  if [ -n "$BIN_PATH" ] && [ -x "$BIN_PATH" ]; then
    "$BIN_PATH" --layout "${left},${right}" >/dev/null 2>&1 &
    return 0
  fi

  osascript <<END
tell application "iTerm"
  activate
  set win to (create window with default profile)
  set leftSessions to {current session of win}
  tell current session of win
    set rightTop to split vertically with default profile
  end tell
  set rightSessions to {rightTop}
  set leftCurrent to current session of win
  repeat $((left - 1)) times
    tell leftCurrent
      set nextS to split horizontally with default profile
    end tell
    set end of leftSessions to nextS
    set leftCurrent to nextS
  end repeat
  set rightCurrent to rightTop
  repeat $((right - 1)) times
    tell rightCurrent
      set nextS to split horizontally with default profile
    end tell
    set end of rightSessions to nextS
    set rightCurrent to nextS
  end repeat
  repeat with i from 1 to (count of leftSessions)
    set name of item i of leftSessions to ("" & i)
  end repeat
  repeat with i from 1 to (count of rightSessions)
    set name of item i of rightSessions to ("" & (${left} + i))
  end repeat
end tell
END
}
