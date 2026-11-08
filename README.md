# Terminal Prop

Dos páginas para operar cuentas de fondeo cubiertas en un bróker:

- **Cálculo** (`index.html`): regla de 3, buscador que iguala el riesgo entre micros MNQ y lotes de NAS100, y rentabilidad de un challenge con cobertura (plan de días, coste acumulado y probabilidad).
- **Registro** (`registro.html`): las cuentas compradas (varias de golpe), las operaciones con su resultado en la firma y en el bróker, retiros y gastos extra. Panel con resultado neto, % de fondeo, % de retiro, % de fallos, lo que el bróker aún tiene que recuperar en cada cuenta y la comparativa con y sin coberturas.

El registro lleva **login**: cada persona entra con su correo y contraseña (se crea la cuenta con un código de invitación; máximo 15 cuentas) y solo ve sus propios datos, desde el móvil o el ordenador. Los datos están en un proyecto de Supabase (`servidor/supabase.sql` crea las tablas): un documento por usuario con número de revisión, protegido con RLS (cada usuario solo lee y escribe el suyo) y las 100 últimas versiones de historial. Si dos aparatos del mismo usuario guardan a la vez, la web junta los cambios por identificador de cuenta y movimiento antes de volver a guardar. Cada aparato tiene una copia local para funcionar sin conexión, y se sincroniza al volver (y cada 15 s con la pestaña abierta). Los datos de ejemplo se quedan solo en el aparato.

Desde «Datos y copias» se descarga una copia, se carga una copia o se exporta a Excel.

La página de cálculo es HTML suelto, sin dependencias. El registro carga `supabase-js` desde jsDelivr. Publicado con GitHub Pages.

**Mantenimiento**
- El proyecto gratis de Supabase se pausa a los 7 días sin uso: la tarea `.github/workflows/latido.yml` hace unas consultas cada día (y se reactiva sola para que GitHub no la apague a los 60 días). Si aun así se pausara, se reanuda con un clic en el panel de Supabase.
- Código de invitación y tope de cuentas: tabla `ajustes` (ver comentarios al final de `servidor/supabase.sql`).
- Si alguien olvida la contraseña: Authentication → Users en Supabase, cambiarla desde ahí. No hay correos de recuperación (el correo gratis de Supabase solo envía al equipo).
