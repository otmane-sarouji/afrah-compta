/* Pont securise entre la page web (isolee, sans acces a Node) et le stockage
   reel sur disque gere par le processus principal Electron.
   Expose window.afrahStorage.{disponible, chargerSync, enregistrerSync} —
   utilise uniquement par app/www/index.html quand l'app tourne sous Electron. */
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('afrahStorage', {
  disponible: true,
  chargerSync: () => ipcRenderer.sendSync('afrah:charger'),
  enregistrerSync: (json) => ipcRenderer.sendSync('afrah:enregistrer', json)
});
