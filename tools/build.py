#!/usr/bin/env python3
"""Genera los archivos listos para pegar en Roblox Studio.

Salidas (carpeta dist/):
  - Install.lua       Instalador TODO EN UNO (mapa + scripts embebidos).
  - InstallMap.lua    Solo el mapa (para pegar en la barra de comandos).
  - HockeyServer.lua  Copia del script de servidor.
  - HockeyClient.lua  Copia del script de cliente.

Uso:  python tools/build.py
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
DIST = ROOT / "dist"

CONFIG = SRC / "shared" / "Config.lua"
SERVER = SRC / "server" / "GameServer.server.lua"
CLIENT = SRC / "client" / "ClientController.client.lua"
TEMPLATE = ROOT / "tools" / "installer.lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip("\n")


def lua_long_string(text: str) -> str:
    """Devuelve `text` como literal Lua de cadena larga, seguro."""
    level = 0
    while True:
        close = "]" + "=" * level + "]"
        if close not in text and "[" + "=" * level + "[" not in text:
            break
        level += 1
    return "[" + "=" * level + "[\n" + text + "\n]" + "=" * level + "]"


def render(with_scripts: bool) -> str:
    out = read(TEMPLATE)
    out = out.replace("__CONFIG_SRC__", lua_long_string(read(CONFIG)))
    if with_scripts:
        out = out.replace("__SERVER_SRC__", lua_long_string(read(SERVER)))
        out = out.replace("__CLIENT_SRC__", lua_long_string(read(CLIENT)))
        out = out.replace("__EMBED_SCRIPTS__", "true")
    else:
        out = out.replace("__SERVER_SRC__", "nil")
        out = out.replace("__CLIENT_SRC__", "nil")
        out = out.replace("__EMBED_SCRIPTS__", "false")

    leftovers = [t for t in ("__CONFIG_SRC__", "__SERVER_SRC__", "__CLIENT_SRC__", "__EMBED_SCRIPTS__") if t in out]
    if leftovers:
        raise SystemExit(f"Placeholders sin reemplazar: {leftovers}")
    return out


def write(name: str, text: str) -> None:
    DIST.mkdir(exist_ok=True)
    path = DIST / name
    path.write_text(text, encoding="utf-8", newline="\r\n")
    print(f"  {name:<18} {path.stat().st_size / 1024:6.1f} KB")


def main() -> None:
    for path in (CONFIG, SERVER, CLIENT, TEMPLATE):
        if not path.exists():
            raise SystemExit(f"Falta el archivo {path}")

    print("Generando dist/:")
    write("Install.lua", render(with_scripts=True))
    write("InstallMap.lua", render(with_scripts=False))
    write("HockeyServer.lua", read(SERVER))
    write("HockeyClient.lua", read(CLIENT))


if __name__ == "__main__":
    main()
