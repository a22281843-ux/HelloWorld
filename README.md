# 🚀 VIBE.DEV | Hello World & GitHub 배포 가이드

> **"Focus on the flow, AI takes care of the rest."**  
> 바이브 코더를 위한 세련된 다크 미니멀 디자인의 인터랙티브 웹 애플리케이션입니다.

---

## 🌟 주요 기능 (Features)

- 🌿 **모던 다크 & 글래스모피즘 디자인**: 눈이 편안한 딥 다크 배경과 섬세한 빛 효과, 부드러운 애니메이션
- ⏱️ **실시간 디지털 시계 & 날짜**: 초 단위로 정밀하게 업데이트되는 시계와 한국어 날짜 표기
- 📍 **실시간 위치 & 타임존 감지**: 브라우저 타임존을 기반으로 사용자의 접속 지역 자동 표시
- 🔗 **빠른 링크 지원**: [sunnyk.store](https://sunnyk.store/) 바로가기 버튼 연동
- 💬 **인터랙티브 아이디어 인풋**: 영감을 즉시 기록하고 인터랙션을 경험할 수 있는 플로우

---

## 📁 프로젝트 구조

```text
HELLO/
├── hello.html       # 메인 웹 애플리케이션 (HTML, CSS, JS 일체형)
├── README.md        # 프로젝트 설명 및 배포 가이드
├── GEMINI.md        # 프로젝트 규칙 및 설정
└── .gitignore       # Git 제외 항목 설정
```

---

## 💻 로컬 실행 방법

별도의 서버 설치 없이 브라우저에서 바로 실행할 수 있습니다.

```powershell
# Windows 기본 브라우저로 실행
start hello.html
```

---

## 🚀 GitHub CLI(`gh`)를 통한 원격 저장소 배포 가이드

GitHub CLI(`gh`)를 사용하면 웹 브라우저 접속 없이 터미널에서 저장소 생성부터 배포까지 한 번에 완료할 수 있습니다.

### 1. GitHub 로그인 상태 확인
```powershell
gh auth status
```

### 2. GitHub 원격 저장소 생성 및 코드 푸시 (최초 1회)
```powershell
# 현재 디렉터리를 기반으로 GitHub에 Public 저장소를 생성하고 즉시 푸시
gh repo create HELLO --public --source=. --remote=origin --push
```

### 3. 변경 사항 커밋 및 푸시
```powershell
# 변경 사항 스테이징 및 커밋
git add .
git commit -m "문서: README 업데이트"

# 원격 저장소로 푸시
git push origin main
```

---

## 🌐 GitHub Pages로 무료 웹 호스팅 배포하기

GitHub Pages를 활성화하여 웹 상에서 누구나 접속할 수 있도록 배포할 수 있습니다.

1. **GitHub Pages 활성화**:
   ```powershell
   # 저장소 브라우저 페이지 바로 열기
   gh repo view --web
   ```
2. **Settings** → **Pages** 이동
3. **Build and deployment** 항목의 **Source**를 `Deploy from a branch`로 선택
4. **Branch**를 `main` / `/(root)`로 설정 후 **Save** 저장
5. 수 분 내에 `https://<사용자이름>.github.io/HELLO/hello.html` 주소로 배포 완료!

---

## 📜 라이선스 및 규칙

- **Git 커밋 규칙**: 모든 커밋 메시지는 한글 컨벤션(`기능:`, `수정:`, `문서:` 등)을 준수합니다.
- **라이선스**: MIT License
