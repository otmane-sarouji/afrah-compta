/* AFRAH COMPTA — processus principal Electron
   L'application charge www/index.html : c'est EXACTEMENT le meme fichier que la
   version navigateur, il n'existe qu'une seule source. */
const { app, BrowserWindow, Menu, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow = null;

/* Les donnees sont stockees dans le profil de l'application, pas dans le navigateur :
   C:\Users\<vous>\AppData\Roaming\AFRAH COMPTA */
function dataDir() { return app.getPath('userData'); }
function backupDir() { return path.join(dataDir(), 'sauvegardes'); }

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1024,
    minHeight: 700,
    show: false,
    title: 'AFRAH COMPTA',
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      spellcheck: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'www', 'index.html'));
  mainWindow.once('ready-to-show', () => mainWindow.show());

  // Les liens externes s'ouvrent dans le navigateur, jamais dans l'application
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });

  buildMenu();
}

function buildMenu() {
  const template = [
    {
      label: 'Fichier',
      submenu: [
        {
          label: 'Ouvrir le dossier des sauvegardes',
          click: () => { fs.mkdirSync(backupDir(), { recursive: true }); shell.openPath(backupDir()); }
        },
        { type: 'separator' },
        { label: 'Imprimer…', accelerator: 'CmdOrCtrl+P', click: () => mainWindow.webContents.print({}) },
        { type: 'separator' },
        { role: 'quit', label: 'Quitter' }
      ]
    },
    {
      label: 'Edition',
      submenu: [
        { role: 'undo', label: 'Annuler' }, { role: 'redo', label: 'Retablir' },
        { type: 'separator' },
        { role: 'cut', label: 'Couper' }, { role: 'copy', label: 'Copier' },
        { role: 'paste', label: 'Coller' }, { role: 'selectAll', label: 'Tout selectionner' }
      ]
    },
    {
      label: 'Affichage',
      submenu: [
        { role: 'reload', label: 'Recharger' },
        { role: 'zoomIn', label: 'Agrandir' }, { role: 'zoomOut', label: 'Reduire' },
        { role: 'resetZoom', label: 'Taille normale' },
        { type: 'separator' },
        { role: 'togglefullscreen', label: 'Plein ecran' },
        { role: 'toggleDevTools', label: 'Outils de developpement' }
      ]
    },
    {
      label: 'Aide',
      submenu: [
        {
          label: 'Ou sont mes donnees ?',
          click: () => dialog.showMessageBox(mainWindow, {
            type: 'info',
            title: 'Emplacement des donnees',
            message: 'Vos donnees sont enregistrees dans :',
            detail: dataDir() + '\n\nLes sauvegardes automatiques sont dans le sous-dossier « sauvegardes ».'
          })
        },
        {
          label: 'A propos',
          click: () => dialog.showMessageBox(mainWindow, {
            type: 'info', title: 'A propos',
            message: 'AFRAH COMPTA ' + app.getVersion(),
            detail: 'Gestion commerciale et comptable — fonctionne entierement hors ligne.'
          })
        }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
