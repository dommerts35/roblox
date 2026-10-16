# Hockey de Mesa 4 Jugadores (Roblox)

Juego de mesa/air-hockey para **4 jugadores**. La arena es un cuadrado con **una
portería en cada lado**: cada jugador defiende la suya y se desliza de lado a lado
para despejar las bolas de su portería. En las **4 esquinas hay pilares** que sueltan
bolas al centro de forma periódica.

Cada jugador es un **rectángulo del color de su lado** (el personaje está oculto):
el rectángulo es a la vez lo que ves y lo que golpea la bola.

La **plataforma está inclinada y va cambiando de ángulo todo el rato**: el desnivel
gira sin parar alrededor de la mesa y la gravedad hace rodar las bolas hacia el lado
bajo, así que nunca puedes relajarte.

Cada jugador tiene su propia **cámara fija** mirando a la mesa desde su lado.

---

## Cómo instalarlo en Studio

Hay dos caminos. Empieza por el **A** y, si la barra de comandos te corta el
pegado, usa el **B** (funciona siempre).

### A) Instalador todo en uno

1. Abre tu `Place1.rbxl` en Roblox Studio.
2. Abre la **barra de comandos**: `View` → `Command Bar`.
3. Abre `dist/Install.lua`, **copia todo** y pégalo en la barra. Pulsa `Enter`.
4. Cuando aparezca en el Output `[Hockey] Instalacion completa`, pulsa **Play**.

> El instalador borra el `Baseplate` por defecto (lo sustituye por la arena) y
> recoloca el `SpawnLocation`. No toca nada más.
> El resultado son instancias reales en el Explorer: puedes editar la arena,
> colores o tamaños a mano y se queda guardado al guardar el place.

### B) Mapa + scripts por separado (a prueba de cortes)

1. Pega `dist/InstallMap.lua` en la barra de comandos y pulsa `Enter`.
   (Solo crea la arena, las porterías, los pilares, los remotes y el módulo `Config`.)
2. En `ServerScriptService` inserta un **Script**, llámalo `HockeyServer` y pega
   dentro `dist/HockeyServer.lua`.
3. En `StarterPlayer` → `StarterPlayerScripts` inserta un **LocalScript**, llámalo
   `HockeyClient` y pega dentro `dist/HockeyClient.lua`.
4. Pulsa **Play**.

### Probar con 4 jugadores

`Test` → `Clients and Servers` → **Players: 4** → `Start`. Cada ventana es un
jugador (usa `View` → `Show Multiple Windows` si quieres verlas a la vez).

---

## Controles

| Acción | Teclas |
| --- | --- |
| Deslizarse a lo largo de tu lado | `A` / `D`, `←` / `→`, `W` / `S`, `↑` / `↓` |
| Mando | Stick izquierdo (X) |

Las cuatro direcciones hacen lo mismo (moverte por tu línea); se mapean según lo
que ves en pantalla, así que "izquierda en pantalla" siempre es la misma tecla.

---

## Reglas

- Cada jugador ocupa un lado: **Sur, Este, Norte y Oeste** (colores rojo, azul,
  verde y amarillo). Se asignan por orden de entrada.
- Cada jugador es un **rectángulo** de 14×9 studs del color de su lado, apoyado en
  el suelo. El personaje que lo controla está **invisible**, así que lo único que
  se ve (y lo que la bola golpea) es el rectángulo.
- Cada lado tiene su **portería** en el centro de su muro: un **hueco de 42 studs**
  sin caja, suelo ni pared detrás, así que la bola que entra desaparece en el acto
  (nunca puede rebotar ni volver a salir). El hueco está marcado con un marco de
  neón del color del lado y su línea de deslizamiento en el suelo.
- **Las bolas van a más**: la partida arranca con **3-5 bolas** y cada 2 s el tope
  sube una más, hasta un máximo de **100 bolas** a la vez. Los **4 pilares** de las
  esquinas las lanzan hacia el centro con ángulo aleatorio y se van turnando, así
  que un lote nunca sale entero del mismo pilar.
- La **mesa se inclina sola y a tirones**: cada 0,35 s elige al azar un ángulo
  nuevo (entre 7° y 15°) y una dirección nueva, con un giro constante por debajo
  que gira unas **150°/s de media** con picos de más de 600°/s. Nada de vaivenes
  suaves: la gravedad cambia de rumbo sin avisar y las bolas salen disparadas a
  cualquier parte. Los jugadores no resbalan: siguen clavados en su línea.
- Golpeas la bola con tu rectángulo para despejarla de tu portería.
- **Vidas**: cada jugador empieza con **30 vidas**. Cada vez que una bola entra en
  su portería pierde **1 vida**, la haya metido quien la haya metido (los autogoles
  cuentan igual).
- Cuando alguien se queda a **0 vidas termina la partida**: gana quien más vidas
  tenga y, tras unos segundos, todos vuelven a 30 y el contador de bolas otra vez
  a 3-5.
- Si entran más de 4 jugadores, los extra aparecen como **espectadores** en la
  grada (pueden caminar por ahí).

---

## Ajustar el juego

Todo se controla desde **`src/shared/Config.lua`** (y su copia dentro de
`ReplicatedStorage.Config` en Studio):

| Sección | Qué cambia |
| --- | --- |
| `Arena` | Tamaño del cuadrado, alto y grosor de muros, ancho del hueco de portería (`GoalWidth`), pilares |
| `Slide` | Velocidad de deslizamiento, distancia de la línea, límites laterales |
| `Paddle` | **Rectángulo de cada jugador**: largo (`Width`), alto (`Height`), grosor (`Depth`) y hueco bajo la pala |
| `Ball` | Bolas iniciales (`StartMin`/`StartMax`), ritmo de subida (`GrowEvery`) y tope (`MaxAlive`), tamaño de lote (`Batch`), velocidad, rebote, fricción |
| `Tilt` | **Inclinación de la mesa**: ángulo mínimo/máximo, cada cuánto cambia (`Step`), fuerza del tirón (`Jitter`), latido (`Pulse`/`WobbleSpeed`), giro base (`TurnSpeed`) y frecuencia de actualización |
| `Match` | **Vidas iniciales** (`StartLives`) y pausa antes de reiniciar |
| `Camera` | Altura, distancia y campo de visión de la cámara |
| `Sides` | Nombre y color de cada lado |

Para **quitar la inclinación** pon `Config.Tilt.Enabled = false` (la mesa se queda
plana). Para más caos todavía: baja `Step` (cambia de idea más a menudo), sube
`Jitter` (tirones más brutales, ±1,1 rad por defecto), sube `TurnSpeed` (giro base
más rápido) o sube `MaxDegrees`. Por encima de ~18° el muro cercano ya tapa parte
del suelo: si lo subes, sube también `Camera.Height`.

Ojo con el pico de bolas: con `MaxAlive = 100` las bolas entran en tandas y las
**30 vidas se agotan en segundos**. Si quieres partidas más largas, sube
`Match.StartLives`, baja `Ball.MaxAlive` o alarga `Ball.GrowEvery`.

Ojo: subir `GoalWidth` es seguro, pero si cambias `Arena.Size` tienes que reescalar
a mano `Slide.LaneDistance` y `Slide.LaneLimit` para que la línea del jugador siga
dentro de los muros y no choque con los pilares.

El ancho de la pala y `Slide.LaneLimit` van juntos: `32 + 14/2 + 3,8` (el muelle
puede pasarse 3,8 studs) se queda en 42,8, y la pala del lado vecino empieza en
44,5. Si ensanchas `Paddle.Width` o subes `LaneLimit`, dos palas vecinas pueden
llegar a tocarse en las esquinas.

La mesa mide ahora **130 studs de lado** (antes 180), con el hueco de portería a 42,
la línea del jugador a 46 del centro y los pilares a 12 del borde.

Si cambias **geometría** (`Arena`) o **posiciones** (`Slide`), vuelve a ejecutar
el instalador para que el mapa se reconstruya con los nuevos valores.

---

## Estructura del proyecto

```
src/shared/Config.lua                  Módulo compartido (va a ReplicatedStorage)
src/server/GameServer.server.lua       Lógica de servidor (bolas, goles, marcador)
src/client/ClientController.client.lua Cámara, controles y HUD
tools/installer.lua                    Plantilla del instalador
tools/build.py                         Genera la carpeta dist/
dist/Install.lua                       Instalador todo en uno  <- el que pegas
dist/InstallMap.lua                    Solo el mapa
dist/HockeyServer.lua / HockeyClient.lua  Copias para pegar manualmente
```

Para regenerar `dist/` después de editar los `src`:

```powershell
python tools/build.py
```

---

## Notas técnicas

- La **mesa inclinada** es física de verdad: la `Arena` es un `Model` con una pieza
  pivote invisible en el centro exacto de la superficie, y el servidor la gira con
  `Model:PivotTo()` hasta 60 veces por segundo. La gravedad real hace rodar las
  bolas hacia el lado bajo y los rebotes siguen siendo idénticos para todos.
- La inclinación es una **función pura del tiempo** (`Config.tiltCFrame(t)`) que se
  calcula con ruido determinista: cada `Step` segundos saca un ángulo y una
  dirección nuevos de un hash, así que da tirones, nunca repite el ciclo y no
  necesita guardar estado (cualquier instante se puede recalcular igual).
- El jugador es un **personaje invisible** con un **rectángulo soldado**
  (`WeldConstraint`) a su `HumanoidRootPart`: el cuerpo sigue chocando (así el
  humanoid se apoya en el suelo como cualquier personaje) pero no se ve, y el
  rectángulo lo cubre entero, de modo que lo que se ve y lo que golpea coinciden.
  Se le quita el `Animate` para que no se meneen las animaciones, y se le apaga el
  nombre y la barra de vida.
- Los jugadores **no resbalan** con la inclinación: el controlador fija cada frame
  su velocidad en el plano XZ (solo se deja libre la Y, que sigue siendo la
  gravedad), así que la componente horizontal de la gravedad nunca les afecta.
- El deslizamiento lo resuelve **el cliente** (respuesta inmediata) escribiendo
  `AssemblyLinearVelocity` sobre su propio personaje; el servidor comprueba cada
  0,5 s que nadie se salga de su zona y lo devuelve a su línea, teniendo en cuenta
  la inclinación actual para no dejarlo bajo el suelo.
- Las **bolas y su física son del servidor**, así que todos ven los mismos
  rebotes y goles. Su velocidad está topada en `Config.Ball.MaxSpeed` para que no
  atraviesen los muros a alta velocidad.
- El **gol se detecta por posición**, no con un sensor: la portería es un hueco en
  el muro sin caja detrás, y el servidor comprueba cada frame si alguna bola ha
  cruzado el plano del muro dentro del ancho del hueco. Al instante la bola se
  elimina, así que es imposible que rebote y vuelva a salir.
- El personaje es la "pala": `WalkSpeed = 0`, sin salto y sin auto-rotación, con
  la velocidad lateral impuesta por el controlador.
- Los scripts usan sintaxis compatible con Lua 5.1/Luau y se validaron con un
  parser antes de generar el instalador.
