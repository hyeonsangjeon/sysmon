# sysmon.sh

가볍게 돌아가는 macOS용 CPU/메모리 터미널 모니터입니다. 외부 의존성 없이 `bash`와 기본 macOS 명령어(`top`, `vm_stat`, `ps`)만으로 동작합니다.

## 미리보기

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    macOS System Monitor          15:17:42
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  CPU  [████████████████░░░░░░░░░░░░░░░░░░░░░░░░]  39.2%
  MEM  [█████████████████████████░░░░░░░░░░░░░░░]  61.5%  14.7G / 24.0G

  ▸ Top 5  CPU
      PID    CPU%    MEM%  PROCESS
      ...

  ▸ Top 5  MEM
      PID    CPU%    MEM%  PROCESS
      ...
```

## 기능

- CPU / 메모리 사용량을 컬러 막대 그래프로 표시 (50% 미만 초록 · 80% 미만 노랑 · 그 이상 빨강)
- CPU·메모리 사용량 상위 5개 프로세스 표시
- 기본 2초 간격 갱신, `q` 키로 종료

## 사용법

```bash
chmod +x sysmon.sh
./sysmon.sh
```

종료하려면 `q` 를 누르세요.

## 메모리 사용량 계산 방식

macOS의 `top` 이 보고하는 `PhysMem ... used` 값에는 언제든 회수 가능한 **파일 캐시**가 포함되어 있어, 그대로 `used / (used + unused)` 로 계산하면 실제와 무관하게 항상 99% 근처로 과장됩니다.

그래서 이 스크립트는 `vm_stat` 기반으로 **Activity Monitor 와 동일한 방식**으로 계산합니다.

```
used = (Wired + Compressed + (Anonymous − Purgeable)) × page size
사용률 = used / 총 RAM(sysctl hw.memsize)
```

## 요구 사항

- macOS
- `bash` (스크립트는 `/usr/bin/env bash` 사용)
