/* AFRAH COMPTA — processus principal Electron
   L'application charge www/index.html : c'est EXACTEMENT le meme fichier que la
   version navigateur, il n'existe qu'une seule source. */
const { app, BrowserWindow, Menu, dialog, shell, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');

let mainWindow = null;

/* ============================================================================
   STOCKAGE DES DONNEES -- fichier reel sur disque, PAS localStorage.
   Auparavant les donnees vivaient uniquement dans le stockage interne du
   navigateur integre (LevelDB Chromium) : n'importe quel nettoyage de cache,
   profil corrompu ou reinstallation les effacait sans recours possible.
   Elles sont maintenant un fichier JSON ordinaire, sauvegardable comme
   n'importe quel document, et des instantanes quotidiens sont conserves
   automatiquement dans un sous-dossier separe.
   ============================================================================ */
function dataDir() { return app.getPath('userData'); }
function backupDir() { return path.join(dataDir(), 'sauvegardes'); }
function fichierDonnees() { return path.join(dataDir(), 'data', 'facturis_state.json'); }

/* Ecriture atomique : on ecrit dans un fichier temporaire puis on renomme.
   Le renommage est atomique sur un meme disque -- si l'application plante ou
   perd l'alimentation en plein milieu, le fichier final n'est jamais a moitie
   ecrit : soit l'ancienne version est intacte, soit la nouvelle l'est. */
function ecrireAtomique(cheminFinal, contenu) {
  fs.mkdirSync(path.dirname(cheminFinal), { recursive: true });
  const tmp = cheminFinal + '.tmp-' + process.pid;
  fs.writeFileSync(tmp, contenu, 'utf8');
  fs.renameSync(tmp, cheminFinal);
}

function chargerDonnees() {
  try {
    if (fs.existsSync(fichierDonnees())) return fs.readFileSync(fichierDonnees(), 'utf8');
  } catch (e) { console.error('Lecture des donnees impossible :', e); }
  return null;
}

let dernierePurgeBackup = 0;
function enregistrerDonnees(json) {
  ecrireAtomique(fichierDonnees(), json);
  ecrireInstantaneQuotidien(json);
}

/* Un instantane par jour calendaire, ecrase s'il existe deja pour aujourd'hui.
   Conserve 30 jours en continu ; purge les plus anciens (verifie au plus une
   fois par heure pour ne pas parcourir le dossier a chaque sauvegarde). */
function ecrireInstantaneQuotidien(json) {
  const jour = new Date().toISOString().slice(0, 10);
  const cible = path.join(backupDir(), 'auto-' + jour + '.json');
  try { ecrireAtomique(cible, json); } catch (e) { console.error('Sauvegarde automatique impossible :', e); }

  const maintenant = Date.now();
  if (maintenant - dernierePurgeBackup < 3600000) return;
  dernierePurgeBackup = maintenant;
  try {
    const LIMITE_JOURS = 30;
    const seuil = maintenant - LIMITE_JOURS * 86400000;
    for (const nom of fs.readdirSync(backupDir())) {
      // format attendu : auto-AAAA-MM-JJ.json -- validation sans regex a backslash
      if (nom.indexOf('auto-') !== 0 || nom.slice(-5) !== '.json') continue;
      const datePart = nom.slice(5, -5);
      const date = new Date(datePart + 'T00:00:00');
      if (isNaN(date.getTime())) continue;
      if (date.getTime() < seuil) fs.unlinkSync(path.join(backupDir(), nom));
    }
  } catch (e) { /* dossier pas encore cree au tout premier lancement */ }
}

ipcMain.on('afrah:charger', (evenement) => { evenement.returnValue = chargerDonnees(); });
ipcMain.on('afrah:enregistrer', (evenement, json) => {
  try { enregistrerDonnees(json); evenement.returnValue = true; }
  catch (e) { console.error('Enregistrement impossible :', e); evenement.returnValue = false; }
});

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
      spellcheck: false,
      preload: path.join(__dirname, 'preload.js')
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
            detail: fichierDonnees() + '\n\nUne sauvegarde automatique est ecrite chaque jour dans :\n' + backupDir() + '\n(30 derniers jours conserves)'})
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
