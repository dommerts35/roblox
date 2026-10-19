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
| Pulso de energía (golpe fuerte) | `Espacio` o `Cuadrado` en el mando |
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
  que un lote nunca sale entero del mismo pilar. Y, como en Ballistix, **las que ya
  ruedan también ganan velocidad** poco a poco (+4 %/s, hasta el tope de 180), así
  que la partida se calienta sola.
- La **mesa se inclina sola y a tirones**: cada 0,35 s elige al azar un ángulo
  nuevo (entre 7° y 15°) y una dirección nueva, con un giro constante por debajo
  que gira unas **150°/s de media** con picos de más de 600°/s. Nada de vaivenes
  suaves: la gravedad cambia de rumbo sin avisar y las bolas salen disparadas a
  cualquier parte. Los jugadores no resbalan: siguen clavados en su línea.
- Golpeas la bola con tu rectángulo para despejarla de tu portería. Si le das con
  una punta, el tiro sale desviado hacia ese lado.
- **Pulso de energía** (`Espacio` / `Cuadrado`): carga el golpe fuerte. La siguiente
  bola que toque la cara delantera sale a **180** en vez de a 120. Si lo gastas sin
  tocar ninguna bola, queda **bloqueado 3 segundos**, así que conviene pulsarlo con
  una bola cerca (es el "extra kick" de Ballistix).
- **Puntos y eliminación**: cada jugador empieza con **30 puntos**. Cada bola que
  entra en su portería le quita **1**, la haya metido quien la haya metido (los
  autogoles cuentan igual).
- Cuando alguien se queda a **0, su nave explota y queda eliminado**: sigue mirando
  la mesa desde su lado, pero ya no juega. **Gana el último que quede** y, tras unos
  segundos, todos vuelven a 30 y el contador de bolas otra vez a 3-5. No hay límite
  de tiempo.
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
| `Hit` | **Golpe de la pala**: fuerza del rebote normal (`Speed`), del **pulso** (`Power`, `PulseWindow`, `PulseLock`), cuánto apunta al golpear en una punta (`Aim`), alcance por delante de la cara (`Reach`) y enfriamiento por bola |
| `Ball` | Bolas iniciales (`StartMin`/`StartMax`), ritmo de subida (`GrowEvery`) y tope (`MaxAlive`), tamaño de lote (`Batch`), velocidad, **aceleración con el tiempo** (`SpeedRamp`), rebote, fricción |
| `Tilt` | **Inclinación de la mesa**: ángulo mínimo/máximo, cada cuánto cambia (`Step`), fuerza del tirón (`Jitter`), latido (`Pulse`/`WobbleSpeed`), giro base (`TurnSpeed`) y frecuencia de actualización |
| `Match` | **Puntos iniciales** (`StartLives`) y pausa antes de reiniciar |
| `Camera` | Altura, distancia y campo de visión de la cámara |
| `Sides` | Nombre y color de cada lado |

Para **quitar la inclinación** pon `Config.Tilt.Enabled = false` (la mesa se queda
plana). Para más caos todavía: baja `Step` (cambia de idea más a menudo), sube
`Jitter` (tirones más brutales, ±1,1 rad por defecto), sube `TurnSpeed` (giro base
más rápido) o sube `MaxDegrees`. Por encima de ~18° el muro cercano ya tapa parte
del suelo: si lo subes, sube también `Camera.Height`.

Ojo con el pico de bolas: con `MaxAlive = 100` las bolas entran en tandas y los
**30 puntos se agotan en segundos**. Si quieres rondas más largas, sube
`Match.StartLives`, baja `Ball.MaxAlive` o alarga `Ball.GrowEvery`. Como ahora el
eliminado se queda fuera hasta que acaba la ronda, si te resulta duro sube los
puntos iniciales. Y si quieres algo más parecido a una mesa de pinball de verdad,
baja `Ball.MaxAlive` a 10-15 (Ballistix llega a 7-8 bolas) y pon `Ball.SpeedRamp`
en 0 si no te gusta que aceleren solas.

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
  conjunto se apoya en el suelo como cualquier personaje) pero no se ve, y el
  rectángulo lo cubre entero, de modo que lo que se ve y lo que golpea coinciden.
  Se le quita el `Animate` para que no se meneen las animaciones, se le apaga el
  nombre y la barra de vida, y se le pone `PlatformStand` para que el humanoid no
  intente mantenerse de pie (peleaba con la inclinación de la mesa).
- La pala va **pegada a la superficie**: el cliente lanza cada frame un rayo hacia
  abajo contra la `Arena`, apoya los pies en el punto donde ha dado y tumba el
  rectángulo con la normal del suelo, así que por muy brusco que sea el tirón de
  la plataforma nunca se queda en el aire ni se cuela por debajo de la mesa (y
  choca contra la mesa de verdad, no contra un plano calculado a mano).
- El servidor no adivina la altura del rig: guarda en el atributo `FeetOffset`
  cuánto hay del root a la planta de los pies (medido con el *bounding box*), y ese
  valor sirve igual para personajes R6 y R15.
- Los jugadores **no resbalan** con la inclinación: el controlador fija cada frame
  su velocidad en el plano XZ y su posición vertical, así que ni la componente
  horizontal ni la vertical de la gravedad les afecta.
- El deslizamiento lo resuelve **el cliente** (respuesta inmediata) escribiendo
  `AssemblyLinearVelocity` sobre su propio personaje; el servidor comprueba cada
  0,5 s que nadie se salga de su zona (ni a lo largo, ni hacia fuera, ni en altura)
  y lo devuelve a su línea, teniendo en cuenta la inclinación actual para no dejarlo
  bajo el suelo.
- Las **bolas y su física son del servidor**, así que todos ven los mismos
  rebotes y goles. Su velocidad está topada en `Config.Ball.MaxSpeed` para que no
  atraviesen los muros a alta velocidad.
- El **gol se detecta por posición**, no con un sensor: la portería es un hueco en
  el muro sin caja detrás, y el servidor comprueba cada frame si alguna bola ha
  cruzado el plano del muro dentro del ancho del hueco. Al instante la bola se
  elimina, así que es imposible que rebote y vuelva a salir.
- El **golpe de la pala** también va por posición, con la bola pasada al espacio de
  la pala (`PointToObjectSpace`): si está delante de la cara que mira al centro,
  dentro del ancho y el alto y a menos de `Hit.Reach` studs, el servidor le pone
  una velocidad nueva hacia el centro. El sensor no se pierde ninguna bola rápida
  porque el alcance es mayor que lo que avanza una bola en un frame (a
  `MaxSpeed = 180`, 3 studs por frame). Como el rectángulo va tumbado con la mesa,
  su `LookVector` sigue el plano del suelo y el tiro sale bien con cualquier
  inclinación. El desvío se calcula con la punta de la pala con la que se golpea
  (`lp.X`), así que se puede apuntar a un lado o a otro. Cada bola lleva un
  enfriamiento (`Hit.Cooldown`) para que no se re-dispare sola.
- El **pulso de energía** abre una ventana de `Hit.PulseWindow` segundos al pulsar
  el remote `Pulse`: la bola que llegue dentro de esa ventana sale a `Hit.Power`
  (180, el tope) en vez de a `Hit.Speed` (120). Si la ventana se cierra sin tocar
  nada, el servidor bloquea el pulso `Hit.PulseLock` segundos y avisa al cliente.
- **Eliminación**: al llegar a 0 el servidor marca el lado como fuera, hace explotar
  el rectángulo (`Explosion` con presión y radio 0: solo el fogonazo), pone al
  jugador el atributo `Out` (el cliente deja de mover la pala) y lo manda a la grada
  con `LoadCharacter`, donde `setupCharacter` lo detecta y le deja caminar. Cuando
  queda uno solo se acaba la ronda y, tras `Match.EndPause`, se recargan todos los
  personajes.
- El personaje es la "pala": `WalkSpeed = 0`, sin salto, sin auto-rotación, con
  `PlatformStand` activado y con la velocidad lateral impuesta por el controlador.
- Los scripts usan sintaxis compatible con Lua 5.1/Luau y se validaron con un
  parser antes de generar el instalador.
