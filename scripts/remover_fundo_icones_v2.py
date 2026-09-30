from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter

BASE = Path(__file__).resolve().parents[1]
INPUT = BASE / "assets" / "images"
OUTPUT = INPUT / "icones_sem_fundo_v2"

TOLERANCE = 34
EDGE_FEATHER = 1.0

ICONES = [
    "icon_administracao.png", "icon_agenda.png", "icon_animais.png",
    "icon_cobertura.png", "icon_configuracoes.png", "icon_cordeiro.png",
    "icon_estoque.png", "icon_farmacia.png", "icon_financeiro.png",
    "icon_manejo.png", "icon_nascimento.png", "icon_ovino_femea.png",
    "icon_ovino_macho.png", "icon_relatorios.png", "icon_reproducao.png",
]

def distancia(a, b):
    return max(abs(a[0]-b[0]), abs(a[1]-b[1]), abs(a[2]-b[2]))

def fundo_da_borda(im):
    px = im.load()
    w, h = im.size
    pontos = [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(0,h//2),(w-1,h//2),(w//2,h-1)]
    cores = [px[x,y][:3] for x,y in pontos]
    return max(set(cores), key=cores.count)

def processar(origem):
    im = Image.open(origem).convert("RGBA")
    w, h = im.size
    px = im.load()
    fundo = fundo_da_borda(im)
    visitado = bytearray(w*h)
    fila = deque()

    def adicionar(x,y):
        i=y*w+x
        if not visitado[i]:
            visitado[i]=1
            fila.append((x,y))

    for x in range(w):
        adicionar(x,0); adicionar(x,h-1)
    for y in range(h):
        adicionar(0,y); adicionar(w-1,y)

    while fila:
        x,y=fila.popleft()
        r,g,b,a=px[x,y]
        valido = a == 0 or distancia((r,g,b),fundo) <= TOLERANCE
        if not valido:
            continue
        if a:
            px[x,y]=(r,g,b,0)
        for nx,ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0<=nx<w and 0<=ny<h:
                i=ny*w+nx
                if not visitado[i]:
                    nr,ng,nb,na=px[nx,ny]
                    if na==0 or distancia((nr,ng,nb),fundo)<=TOLERANCE:
                        visitado[i]=1
                        fila.append((nx,ny))

    alpha=im.getchannel("A")
    if EDGE_FEATHER:
        alpha=alpha.filter(ImageFilter.GaussianBlur(EDGE_FEATHER))
        alpha=alpha.point(lambda v: 0 if v < 12 else v)
    im.putalpha(alpha)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    destino=OUTPUT/origem.name
    im.save(destino,"PNG",optimize=True)
    return destino

for nome in ICONES:
    origem=INPUT/nome
    if not origem.exists():
        print(f"[IGNORADO] {nome}")
        continue
    try:
        print(f"[OK] {nome} -> {processar(origem)}")
    except Exception as e:
        print(f"[ERRO] {nome}: {e}")

print("\nConcluído. Compare a pasta icones_sem_fundo_v2 antes de substituir os arquivos atuais.")
