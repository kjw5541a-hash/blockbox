# NotoSansKR-subset.ttf

Noto Sans KR (SIL Open Font License 1.1, `OFL.txt`) 의 부분집합.

웹 빌드에는 시스템 폰트가 없다. Godot 내장 폰트에는 한글 글리프가 없으므로
폰트를 넣지 않으면 아이폰 사파리에서 한글이 전부 깨져 나온다. 데스크톱에서는
OS 폰트로 대체되어 문제가 드러나지 않는다.

원본은 10MB 라 그대로 넣지 않고, 실제로 쓰는 글자만 남겨 33KB 로 줄였다.

## 다시 만드는 법

`scenes/*.tscn` 과 `scripts/*.gd` 의 문자열 리터럴에 쓰인 글자만 남긴다.
`tests/test_font.gd` 가 같은 규칙으로 훑어 빠진 글자가 없는지 검사하므로,
한글 문구를 새로 추가했다면 아래를 다시 돌리고 테스트를 실행할 것.

```sh
pip install fonttools brotli
curl -fsSLo NotoSansKR.ttf \
  'https://github.com/google/fonts/raw/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf'
python3 - <<'PY' > chars.txt
import re, glob
chars = set(chr(c) for c in range(0x20, 0x7f))
lit = re.compile(r'"((?:[^"\\]|\\.)*)"')
for f in glob.glob('scenes/*.tscn') + glob.glob('scripts/*.gd'):
    for line in open(f, encoding='utf-8'):
        s = line.lstrip()
        if s.startswith('#') or s.startswith(';'):
            continue
        for m in lit.findall(line):
            chars.update(m)
print(''.join(sorted(chars)), end='')
PY
pyftsubset NotoSansKR.ttf --text-file=chars.txt \
  --output-file=assets/fonts/NotoSansKR-subset.ttf \
  --layout-features='' --no-hinting --desubroutinize \
  --drop-tables+=DSIG --name-IDs='*' --notdef-outline
```

이 폰트에 없는 글자는 네모(두부)로 나온다. `⟳` 같은 기호는 Noto Sans KR 자체에
없으니 부분집합을 다시 떠도 생기지 않는다 — 문구를 바꿀 것.
