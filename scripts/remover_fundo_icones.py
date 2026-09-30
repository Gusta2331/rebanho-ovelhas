
from pathlib import Path
from PIL import Image

# Pasta do projeto
PROJETO = Path(__file__).resolve().parent.parent

# Onde estão os ícones atuais
PASTA_ORIGEM = PROJETO / "assets" / "images"

# Onde serão salvas as versões sem fundo
PASTA_DESTINO = PASTA_ORIGEM / "icones_sem_fundo"

# Ícones internos que vamos processar
ICONES = [
    "icon_administracao.png",
    "icon_agenda.png",
    "icon_animais.png",
    "icon_cobertura.png",
    "icon_configuracoes.png",
    "icon_cordeiro.png",
    "icon_estoque.png",
    "icon_farmacia.png",
    "icon_financeiro.png",
    "icon_manejo.png",
    "icon_nascimento.png",
    "icon_ovino_femea.png",
    "icon_ovino_macho.png",
    "icon_relatorios.png",
    "icon_reproducao.png",
]


def distancia_cor(c1, c2):
    """Calcula a diferença simples entre duas cores RGB."""
    return (
        abs(c1[0] - c2[0])
        + abs(c1[1] - c2[1])
        + abs(c1[2] - c2[2])
    )


def descobrir_cor_fundo(imagem):
    """
    Usa os pixels dos cantos para descobrir a cor predominante
    do fundo da imagem.
    """
    largura, altura = imagem.size

    pontos = [
        (0, 0),
        (largura - 1, 0),
        (0, altura - 1),
        (largura - 1, altura - 1),
        (largura // 2, 0),
        (largura // 2, altura - 1),
        (0, altura // 2),
        (largura - 1, altura // 2),
    ]

    cores = []

    for ponto in pontos:
        r, g, b, a = imagem.getpixel(ponto)
        if a > 0:
            cores.append((r, g, b))

    if not cores:
        return (255, 255, 255)

    # Procura a cor mais frequente nos cantos.
    melhor_cor = cores[0]
    melhor_quantidade = 0

    for cor in cores:
        quantidade = sum(
            1
            for outra in cores
            if distancia_cor(cor, outra) <= 30
        )

        if quantidade > melhor_quantidade:
            melhor_quantidade = quantidade
            melhor_cor = cor

    return melhor_cor


def remover_fundo(caminho_origem, caminho_destino):
    imagem = Image.open(caminho_origem).convert("RGBA")

    cor_fundo = descobrir_cor_fundo(imagem)

    pixels = imagem.load()
    largura, altura = imagem.size

    # Tolerância para cores semelhantes ao fundo.
    # Um valor moderado evita apagar partes verdes do desenho.
    tolerancia = 45

    for y in range(altura):
        for x in range(largura):
            r, g, b, a = pixels[x, y]

            if a == 0:
                continue

            distancia = distancia_cor(
                (r, g, b),
                cor_fundo,
            )

            if distancia <= tolerancia:
                pixels[x, y] = (r, g, b, 0)

    caminho_destino.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    imagem.save(
        caminho_destino,
        "PNG",
        optimize=True,
    )


def main():
    print()
    print("=" * 60)
    print(" REMOÇÃO DE FUNDO DOS ÍCONES")
    print("=" * 60)
    print()

    if not PASTA_ORIGEM.exists():
        print("ERRO: pasta assets/images não encontrada.")
        return

    PASTA_DESTINO.mkdir(
        parents=True,
        exist_ok=True,
    )

    processados = 0
    ignorados = 0

    for nome in ICONES:
        origem = PASTA_ORIGEM / nome
        destino = PASTA_DESTINO / nome

        if not origem.exists():
            print(f"[IGNORADO] {nome} não encontrado.")
            ignorados += 1
            continue

        try:
            remover_fundo(origem, destino)
            print(f"[OK] {nome}")
            processados += 1
        except Exception as erro:
            print(f"[ERRO] {nome}: {erro}")

    print()
    print("=" * 60)
    print(f"Processados: {processados}")
    print(f"Ignorados:   {ignorados}")
    print("=" * 60)
    print()
    print("As novas imagens estão em:")
    print(PASTA_DESTINO)
    print()
    print("Os arquivos originais NÃO foram alterados.")


if __name__ == "__main__":
    main()
