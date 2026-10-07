#!/usr/bin/env python3
import math
import socket
import shutil
from datetime import datetime


def memoria_libre_gb():
    with open("/proc/meminfo") as f:
        for linea in f:
            if linea.startswith("MemAvailable"):
                kb = int(linea.split()[1])
                return kb / 1024 / 1024
    return None


def main():
    total, usado, libre = shutil.disk_usage("/")
    porcentaje = math.ceil(usado / (usado + libre) * 100)
    print(f"Equipo: {socket.gethostname()}")
    print(f"Disco usado: {porcentaje:.0f}%")
    mem = memoria_libre_gb()
    if mem is None:
        print("Memoria disponible: no se pudo leer")
    else:
        print(f"Memoria disponible: {mem:.1f} GB")
    print(f"Fecha: {datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
