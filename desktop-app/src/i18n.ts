// ============================================
// Internationalization System
// ============================================

type TranslationKey = string;
type Translations = Record<string, string>;

const translations: Record<string, Translations> = {
  en: {
    // App Title
    'app.title': 'Localhost Manager',

    // Header
    'header.toggleServices': 'Toggle Services',

    // Sidebar
    'sidebar.searchHosts': 'Search hosts...',
    'sidebar.addHost': 'Add Host',
    'sidebar.addGroup': 'Add Group',
    'sidebar.webManager': 'Open Web Manager',
    'sidebar.vscode': 'Open in VSCode',
    'sidebar.backup': 'Backup Manager',
    'sidebar.serverStack': 'Server Stack',
    'sidebar.startApache': 'Start Apache',
    'sidebar.stopApache': 'Stop Apache',
    'sidebar.restartApache': 'Restart Apache',
    'sidebar.toggleAll': 'Toggle All Services',
    'sidebar.generateConfigs': 'Generate & Apply Configs',

    // Main Content
    'main.selectHost': 'Select a virtual host',
    'main.selectHostDesc': 'Choose a host from the sidebar to view details',
    'main.open': 'Open',

    // Host Details
    'details.hostInfo': 'Host Information',
    'details.domain': 'Domain',
    'details.docroot': 'Document Root',
    'details.group': 'Group',
    'details.status': 'Status',
    'details.active': 'Active',
    'details.inactive': 'Inactive',
    'details.sslEnabled': 'SSL Enabled',
    'details.aliases': 'Aliases',
    'details.addAlias': 'Add Alias',

    // Server Versions
    'versions.title': 'Server Software Versions',
    'versions.php': 'PHP Version',
    'versions.apache': 'Apache Version',
    'versions.mysql': 'MySQL Version',
    'versions.current': 'Current',
    'versions.detecting': 'Detecting...',
    'versions.notInstalled': 'Not installed',
    'versions.installMore': 'Install More',

    // Modal
    'modal.addHost': 'Add Virtual Host',
    'modal.editHost': 'Edit Virtual Host',
    'modal.domain': 'Domain',
    'modal.domainPlaceholder': 'example.test',
    'modal.docroot': 'Document Root',
    'modal.docrootPlaceholder': '/Users/mario/Sites/localhost/myproject',
    'modal.group': 'Group',
    'modal.groupPlaceholder': 'Uncategorized',
    'modal.type': 'Type',
    'modal.active': 'Active',
    'modal.ssl': 'SSL Enabled',
    'modal.aliases': 'Aliases',
    'modal.aliasesPlaceholder': 'www.example.test\\nalias.example.test',
    'modal.aliasesHint': 'One alias per line',
    'modal.cancel': 'Cancel',
    'modal.save': 'Save Host',

    // Stack Options
    'stack.native': 'Native (Homebrew)',
    'stack.mamp': 'MAMP / MAMP PRO',
    'stack.xampp': 'XAMPP',
    'stack.wamp': 'WAMP / WampServer',
    'stack.laragon': 'Laragon',
    'stack.custom': 'Custom Path',

    // Type Options
    'type.static': 'Static',
    'type.php': 'PHP',
    'type.vue': 'Vue',
    'type.react': 'React',

    // Toasts
    'toast.hostAdded': 'Host added successfully. Remember to generate configs!',
    'toast.hostUpdated': 'Host updated successfully',
    'toast.groupRenamed': 'Group renamed successfully',
    'toast.configGenerated': 'Configurations generated successfully',
    'toast.servicesToggled': 'Services toggled successfully',
  },

  es: {
    // App Title
    'app.title': 'Gestor de Localhost',

    // Header
    'header.toggleServices': 'Alternar Servicios',

    // Sidebar
    'sidebar.searchHosts': 'Buscar hosts...',
    'sidebar.addHost': 'Agregar Host',
    'sidebar.addGroup': 'Agregar Grupo',
    'sidebar.webManager': 'Abrir Web Manager',
    'sidebar.vscode': 'Abrir en VSCode',
    'sidebar.backup': 'Gestor de Copias',
    'sidebar.serverStack': 'Stack de Servidor',
    'sidebar.startApache': 'Iniciar Apache',
    'sidebar.stopApache': 'Detener Apache',
    'sidebar.restartApache': 'Reiniciar Apache',
    'sidebar.toggleAll': 'Alternar Todos',
    'sidebar.generateConfigs': 'Generar y Aplicar Configs',

    // Main Content
    'main.selectHost': 'Selecciona un host virtual',
    'main.selectHostDesc': 'Elige un host de la barra lateral para ver detalles',
    'main.open': 'Abrir',

    // Host Details
    'details.hostInfo': 'Información del Host',
    'details.domain': 'Dominio',
    'details.docroot': 'Raíz de Documentos',
    'details.group': 'Grupo',
    'details.status': 'Estado',
    'details.active': 'Activo',
    'details.inactive': 'Inactivo',
    'details.sslEnabled': 'SSL Habilitado',
    'details.aliases': 'Alias',
    'details.addAlias': 'Agregar Alias',

    // Server Versions
    'versions.title': 'Versiones de Software del Servidor',
    'versions.php': 'Versión de PHP',
    'versions.apache': 'Versión de Apache',
    'versions.mysql': 'Versión de MySQL',
    'versions.current': 'Actual',
    'versions.detecting': 'Detectando...',
    'versions.notInstalled': 'No instalado',
    'versions.installMore': 'Instalar Más',

    // Modal
    'modal.addHost': 'Agregar Host Virtual',
    'modal.editHost': 'Editar Host Virtual',
    'modal.domain': 'Dominio',
    'modal.domainPlaceholder': 'ejemplo.test',
    'modal.docroot': 'Raíz de Documentos',
    'modal.docrootPlaceholder': '/Users/mario/Sites/localhost/miproyecto',
    'modal.group': 'Grupo',
    'modal.groupPlaceholder': 'Sin categoría',
    'modal.type': 'Tipo',
    'modal.active': 'Activo',
    'modal.ssl': 'SSL Habilitado',
    'modal.aliases': 'Alias',
    'modal.aliasesPlaceholder': 'www.ejemplo.test\\nalias.ejemplo.test',
    'modal.aliasesHint': 'Un alias por línea',
    'modal.cancel': 'Cancelar',
    'modal.save': 'Guardar Host',

    // Stack Options
    'stack.native': 'Nativo (Homebrew)',
    'stack.mamp': 'MAMP / MAMP PRO',
    'stack.xampp': 'XAMPP',
    'stack.wamp': 'WAMP / WampServer',
    'stack.laragon': 'Laragon',
    'stack.custom': 'Ruta Personalizada',

    // Type Options
    'type.static': 'Estático',
    'type.php': 'PHP',
    'type.vue': 'Vue',
    'type.react': 'React',

    // Toasts
    'toast.hostAdded': '¡Host agregado exitosamente! Recuerda generar las configuraciones.',
    'toast.hostUpdated': 'Host actualizado exitosamente',
    'toast.groupRenamed': 'Grupo renombrado exitosamente',
    'toast.configGenerated': 'Configuraciones generadas exitosamente',
    'toast.servicesToggled': 'Servicios alternados exitosamente',
  },

  fr: {
    // App Title
    'app.title': 'Gestionnaire Localhost',

    // Header
    'header.toggleServices': 'Basculer les Services',

    // Sidebar
    'sidebar.searchHosts': 'Rechercher des hôtes...',
    'sidebar.addHost': 'Ajouter un Hôte',
    'sidebar.addGroup': 'Ajouter un Groupe',
    'sidebar.webManager': 'Ouvrir Web Manager',
    'sidebar.vscode': 'Ouvrir dans VSCode',
    'sidebar.backup': 'Gestionnaire de Sauvegarde',
    'sidebar.serverStack': 'Stack Serveur',
    'sidebar.startApache': 'Démarrer Apache',
    'sidebar.stopApache': 'Arrêter Apache',
    'sidebar.restartApache': 'Redémarrer Apache',
    'sidebar.toggleAll': 'Basculer Tous',
    'sidebar.generateConfigs': 'Générer et Appliquer',

    // Main Content
    'main.selectHost': 'Sélectionnez un hôte virtuel',
    'main.selectHostDesc': 'Choisissez un hôte dans la barre latérale',
    'main.open': 'Ouvrir',

    // Host Details
    'details.hostInfo': 'Informations sur l\'Hôte',
    'details.domain': 'Domaine',
    'details.docroot': 'Racine des Documents',
    'details.group': 'Groupe',
    'details.status': 'Statut',
    'details.active': 'Actif',
    'details.inactive': 'Inactif',
    'details.sslEnabled': 'SSL Activé',
    'details.aliases': 'Alias',
    'details.addAlias': 'Ajouter un Alias',

    // Server Versions
    'versions.title': 'Versions des Logiciels Serveur',
    'versions.php': 'Version PHP',
    'versions.apache': 'Version Apache',
    'versions.mysql': 'Version MySQL',
    'versions.current': 'Actuelle',
    'versions.detecting': 'Détection...',
    'versions.notInstalled': 'Non installé',
    'versions.installMore': 'Installer Plus',

    // Modal
    'modal.addHost': 'Ajouter un Hôte Virtuel',
    'modal.editHost': 'Modifier l\'Hôte Virtuel',
    'modal.domain': 'Domaine',
    'modal.domainPlaceholder': 'exemple.test',
    'modal.docroot': 'Racine des Documents',
    'modal.docrootPlaceholder': '/Users/mario/Sites/localhost/monprojet',
    'modal.group': 'Groupe',
    'modal.groupPlaceholder': 'Non catégorisé',
    'modal.type': 'Type',
    'modal.active': 'Actif',
    'modal.ssl': 'SSL Activé',
    'modal.aliases': 'Alias',
    'modal.aliasesPlaceholder': 'www.exemple.test\\nalias.exemple.test',
    'modal.aliasesHint': 'Un alias par ligne',
    'modal.cancel': 'Annuler',
    'modal.save': 'Enregistrer',

    // Stack Options
    'stack.native': 'Natif (Homebrew)',
    'stack.mamp': 'MAMP / MAMP PRO',
    'stack.xampp': 'XAMPP',
    'stack.wamp': 'WAMP / WampServer',
    'stack.laragon': 'Laragon',
    'stack.custom': 'Chemin Personnalisé',

    // Type Options
    'type.static': 'Statique',
    'type.php': 'PHP',
    'type.vue': 'Vue',
    'type.react': 'React',

    // Toasts
    'toast.hostAdded': 'Hôte ajouté avec succès. N\'oubliez pas de générer les configs!',
    'toast.hostUpdated': 'Hôte mis à jour avec succès',
    'toast.groupRenamed': 'Groupe renommé avec succès',
    'toast.configGenerated': 'Configurations générées avec succès',
    'toast.servicesToggled': 'Services basculés avec succès',
  },

  de: {
    // App Title
    'app.title': 'Localhost Manager',

    // Header
    'header.toggleServices': 'Dienste Umschalten',

    // Sidebar
    'sidebar.searchHosts': 'Hosts suchen...',
    'sidebar.addHost': 'Host Hinzufügen',
    'sidebar.addGroup': 'Gruppe Hinzufügen',
    'sidebar.webManager': 'Web Manager Öffnen',
    'sidebar.vscode': 'In VSCode Öffnen',
    'sidebar.backup': 'Backup-Manager',
    'sidebar.serverStack': 'Server-Stack',
    'sidebar.startApache': 'Apache Starten',
    'sidebar.stopApache': 'Apache Stoppen',
    'sidebar.restartApache': 'Apache Neustarten',
    'sidebar.toggleAll': 'Alle Umschalten',
    'sidebar.generateConfigs': 'Configs Generieren',

    // Main Content
    'main.selectHost': 'Wählen Sie einen virtuellen Host',
    'main.selectHostDesc': 'Wählen Sie einen Host aus der Seitenleiste',
    'main.open': 'Öffnen',

    // Host Details
    'details.hostInfo': 'Host-Informationen',
    'details.domain': 'Domain',
    'details.docroot': 'Dokumentenstamm',
    'details.group': 'Gruppe',
    'details.status': 'Status',
    'details.active': 'Aktiv',
    'details.inactive': 'Inaktiv',
    'details.sslEnabled': 'SSL Aktiviert',
    'details.aliases': 'Aliase',
    'details.addAlias': 'Alias Hinzufügen',

    // Server Versions
    'versions.title': 'Server-Software-Versionen',
    'versions.php': 'PHP-Version',
    'versions.apache': 'Apache-Version',
    'versions.mysql': 'MySQL-Version',
    'versions.current': 'Aktuell',
    'versions.detecting': 'Erkennung...',
    'versions.notInstalled': 'Nicht installiert',
    'versions.installMore': 'Mehr Installieren',

    // Modal
    'modal.addHost': 'Virtuellen Host Hinzufügen',
    'modal.editHost': 'Virtuellen Host Bearbeiten',
    'modal.domain': 'Domain',
    'modal.domainPlaceholder': 'beispiel.test',
    'modal.docroot': 'Dokumentenstamm',
    'modal.docrootPlaceholder': '/Users/mario/Sites/localhost/meinprojekt',
    'modal.group': 'Gruppe',
    'modal.groupPlaceholder': 'Unkategorisiert',
    'modal.type': 'Typ',
    'modal.active': 'Aktiv',
    'modal.ssl': 'SSL Aktiviert',
    'modal.aliases': 'Aliase',
    'modal.aliasesPlaceholder': 'www.beispiel.test\\nalias.beispiel.test',
    'modal.aliasesHint': 'Ein Alias pro Zeile',
    'modal.cancel': 'Abbrechen',
    'modal.save': 'Host Speichern',

    // Stack Options
    'stack.native': 'Nativ (Homebrew)',
    'stack.mamp': 'MAMP / MAMP PRO',
    'stack.xampp': 'XAMPP',
    'stack.wamp': 'WAMP / WampServer',
    'stack.laragon': 'Laragon',
    'stack.custom': 'Benutzerdefinierter Pfad',

    // Type Options
    'type.static': 'Statisch',
    'type.php': 'PHP',
    'type.vue': 'Vue',
    'type.react': 'React',

    // Toasts
    'toast.hostAdded': 'Host erfolgreich hinzugefügt. Vergessen Sie nicht, Configs zu generieren!',
    'toast.hostUpdated': 'Host erfolgreich aktualisiert',
    'toast.groupRenamed': 'Gruppe erfolgreich umbenannt',
    'toast.configGenerated': 'Konfigurationen erfolgreich generiert',
    'toast.servicesToggled': 'Dienste erfolgreich umgeschaltet',
  },

  pt: {
    // App Title
    'app.title': 'Gestor de Localhost',

    // Header
    'header.toggleServices': 'Alternar Serviços',

    // Sidebar
    'sidebar.searchHosts': 'Pesquisar hosts...',
    'sidebar.addHost': 'Adicionar Host',
    'sidebar.addGroup': 'Adicionar Grupo',
    'sidebar.webManager': 'Abrir Web Manager',
    'sidebar.vscode': 'Abrir no VSCode',
    'sidebar.backup': 'Gestor de Backup',
    'sidebar.serverStack': 'Stack de Servidor',
    'sidebar.startApache': 'Iniciar Apache',
    'sidebar.stopApache': 'Parar Apache',
    'sidebar.restartApache': 'Reiniciar Apache',
    'sidebar.toggleAll': 'Alternar Todos',
    'sidebar.generateConfigs': 'Gerar e Aplicar Configs',

    // Main Content
    'main.selectHost': 'Selecione um host virtual',
    'main.selectHostDesc': 'Escolha um host da barra lateral para ver detalhes',
    'main.open': 'Abrir',

    // Host Details
    'details.hostInfo': 'Informações do Host',
    'details.domain': 'Domínio',
    'details.docroot': 'Raiz de Documentos',
    'details.group': 'Grupo',
    'details.status': 'Status',
    'details.active': 'Ativo',
    'details.inactive': 'Inativo',
    'details.sslEnabled': 'SSL Ativado',
    'details.aliases': 'Aliases',
    'details.addAlias': 'Adicionar Alias',

    // Server Versions
    'versions.title': 'Versões de Software do Servidor',
    'versions.php': 'Versão do PHP',
    'versions.apache': 'Versão do Apache',
    'versions.mysql': 'Versão do MySQL',
    'versions.current': 'Atual',
    'versions.detecting': 'Detectando...',
    'versions.notInstalled': 'Não instalado',
    'versions.installMore': 'Instalar Mais',

    // Modal
    'modal.addHost': 'Adicionar Host Virtual',
    'modal.editHost': 'Editar Host Virtual',
    'modal.domain': 'Domínio',
    'modal.domainPlaceholder': 'exemplo.test',
    'modal.docroot': 'Raiz de Documentos',
    'modal.docrootPlaceholder': '/Users/mario/Sites/localhost/meuprojeto',
    'modal.group': 'Grupo',
    'modal.groupPlaceholder': 'Sem categoria',
    'modal.type': 'Tipo',
    'modal.active': 'Ativo',
    'modal.ssl': 'SSL Ativado',
    'modal.aliases': 'Aliases',
    'modal.aliasesPlaceholder': 'www.exemplo.test\\nalias.exemplo.test',
    'modal.aliasesHint': 'Um alias por linha',
    'modal.cancel': 'Cancelar',
    'modal.save': 'Salvar Host',

    // Stack Options
    'stack.native': 'Nativo (Homebrew)',
    'stack.mamp': 'MAMP / MAMP PRO',
    'stack.xampp': 'XAMPP',
    'stack.wamp': 'WAMP / WampServer',
    'stack.laragon': 'Laragon',
    'stack.custom': 'Caminho Personalizado',

    // Type Options
    'type.static': 'Estático',
    'type.php': 'PHP',
    'type.vue': 'Vue',
    'type.react': 'React',

    // Toasts
    'toast.hostAdded': 'Host adicionado com sucesso. Lembre-se de gerar as configs!',
    'toast.hostUpdated': 'Host atualizado com sucesso',
    'toast.groupRenamed': 'Grupo renomeado com sucesso',
    'toast.configGenerated': 'Configurações geradas com sucesso',
    'toast.servicesToggled': 'Serviços alternados com sucesso',
  },
};

let currentLanguage = 'en';

export function t(key: TranslationKey): string {
  return translations[currentLanguage]?.[key] || translations.en[key] || key;
}

export function setLanguage(lang: string) {
  if (translations[lang]) {
    currentLanguage = lang;
    updateUI();
  }
}

export function getCurrentLanguage(): string {
  return currentLanguage;
}

function updateUI() {
  // Update all elements with data-i18n attribute
  document.querySelectorAll('[data-i18n]').forEach(element => {
    const key = element.getAttribute('data-i18n');
    if (key) {
      if (element.tagName === 'INPUT' && element.getAttribute('type') !== 'submit') {
        (element as HTMLInputElement).placeholder = t(key);
      } else {
        element.textContent = t(key);
      }
    }
  });

  // Update title attributes (tooltips)
  document.querySelectorAll('[data-i18n-title]').forEach(element => {
    const key = element.getAttribute('data-i18n-title');
    if (key) {
      element.setAttribute('title', t(key));
    }
  });

  // Update option values in selects
  document.querySelectorAll('[data-i18n-option]').forEach(element => {
    const key = element.getAttribute('data-i18n-option');
    if (key) {
      element.textContent = t(key);
    }
  });
}

// Initialize on load
export function initI18n(lang: string = 'en') {
  currentLanguage = lang;
  updateUI();
}
