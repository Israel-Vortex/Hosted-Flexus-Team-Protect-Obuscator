# FlexusHub · Protection V3

Loader protegido para ejecutores de Roblox.

## Setup
1. Sube este proyecto a Vercel
2. Variables de entorno:
   - `SCRIPT_SECRET` = (genera uno fuerte)
   - `PUBLIC_WEB_URL` = https://flexushub-scripts.netlify.app
3. Coloca tu script real en `private/script.lua`
4. Loader:
```lua
loadstring(game:HttpGet("https://TU-PROYECTO.vercel.app/api/loader"))()
```

Web oficial: https://flexushub-scripts.netlify.app  
Discord: https://discord.gg/Fn74MpzFUn
