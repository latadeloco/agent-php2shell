# Glosario

Términos que aparecen en la documentación y en los informes, explicados de forma sencilla.

## CVE

Número público que identifica un fallo de seguridad conocido. Sirve para que todo el mundo hable del mismo problema.

## php2shell

Nombre con el que se conocen los dos fallos que comprueba esta herramienta:

- CVE-2026-109618
- CVE-2026-109619

## PHP

Lenguaje de programación que utilizan muchas páginas web. El servidor lo ejecuta para generar las páginas que ve el visitante.

## PHP-FPM

Programa que ejecuta PHP en el servidor. Si deja de responder, la web puede mostrar errores temporales.

## mod_php

Otra forma de ejecutar PHP dentro del servidor web. La herramienta también contempla este modo.

## SAPI

Forma concreta en la que el servidor ejecuta PHP. Los dos modos más habituales son PHP-FPM y mod_php.

## X-Powered-By

Cabecera que algunos servidores envían para indicar qué versión de PHP utilizan. No siempre aparece y puede ser incorrecta.

## Escáner

Programa que comprueba si el fallo está presente. En esta documentación, el escáner es el de Assetnote.

## Preflight

Revisión previa que comprueba que las herramientas necesarias están instaladas y que los permisos son correctos. No envía tráfico al servidor que se va a revisar.

## Triaje

Revisión de solo lectura que busca señales de un ataque anterior. No modifica el servidor.

## Wrapper

Programa pequeño que envuelve a otro para añadir comprobaciones de seguridad. En esta documentación, los wrappers son los comandos internos que usa el agente.

## Informe

Archivo donde se guarda el resultado de una revisión. Puede ser un archivo `.json` del escáner o un archivo `.txt` del triaje.

## uv

Herramienta que descarga y ejecuta el escáner con sus dependencias. Evita tener que instalar Python y sus librerías a mano.

## Dependencia

Programa o librería que otra herramienta necesita para funcionar. `uv` se encarga de las dependencias del escáner.

## WSL

Subsistema de Windows que permite ejecutar Linux dentro de Windows. Útil si prefiere un entorno Linux.

## Git Bash

Terminal incluida en Git for Windows que permite ejecutar comandos de estilo Linux en Windows.

## HTTP 502

Error que indica que el servidor web no ha podido comunicarse con el servicio que ejecuta la aplicación. En esta herramienta puede aparecer si PHP deja de responder durante la prueba.

## Worker

Proceso que atiende una petición. Si un worker de PHP se detiene, la petición puede fallar.

## Dominio público

Dirección accesible desde Internet, como `https://ejemplo.example`. No es lo mismo que `localhost` o una red privada.

## localhost

Dirección que apunta a su propio ordenador. Se usa para probar aplicaciones que se ejecutan en local.

## Red privada

Red interna que no está expuesta directamente a Internet.

## Autorización

Permiso explícito para probar un servidor. Si el servidor no es suyo, debe obtenerlo por escrito.

## Solo lectura

Que no modifica nada. El triaje es de solo lectura: lee información, pero no cambia archivos ni configuraciones.

## Simulación

Ejecución que muestra lo que se haría sin llevar a cabo la acción real. La opción de simulación del escáner no envía tráfico.
