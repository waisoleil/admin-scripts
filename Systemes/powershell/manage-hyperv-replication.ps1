#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

<#
.SYNOPSIS
    Toolkit interactif de gestion de VM Hyper-V avec réplication Hyper-V Replica.
.DESCRIPTION
    Menu interactif pour créer, lister, supprimer des VM, suivre le statut des réplications,
    nettoyer les réplicas orphelins et réparer la réplication entre deux hôtes Hyper-V.
    Configuration via la hashtable $Config en tête de script.
.EXAMPLE
    .\manage-hyperv-replication.ps1
.NOTES
    Prérequis :
        - Windows Server avec rôle Hyper-V installé sur les 2 hôtes
        - PowerShell Remoting activé (port 5985/5986) entre les 2 hôtes
        - Hôtes dans le même domaine AD (Kerberos) ou config Certificate (HTTPS)
        - Droits admin sur les 2 hôtes
    Auteur  : Nathan WAÏ LUNE (waisoleil)
    Version : 3.0
#>

# ============================================================
# CONFIGURATION - Modifiez ces variables selon votre environnement
# ============================================================

$Config = @{
    # Nom du serveur réplica (le partenaire de réplication)
    # IMPORTANT : Remplacez par le hostname réel du serveur 2 (ex: "SRV-HV02")
    ServeurReplica       = "SRV-HV02"

    # Chemin de stockage des VM (VHDX + config)
    CheminVMs            = "D:\VMs"

    # Chemin de stockage des réplicas reéus (sur le serveur distant)
    CheminReplicas       = "D:\Replicas"

    # Chemin du dossier contenant les ISOs
    CheminISOs           = "D:\ISOs"

    # Fréquence de réplication (300 = 5min, 900 = 15min)
    FrequenceReplication = 900

    # Port de réplication (80 = HTTP avec Kerberos)
    PortReplication      = 80

    # Type d'authentification (Kerberos pour domaine AD, Certificate pour HTTPS/443)
    AuthReplication      = "Kerberos"

    # Compression de la réplication
    CompressionReplication = $true
}

# ============================================================
# FONCTIONS UTILITAIRES
# ============================================================

function Get-CheminLog {
    $dossierScript = Split-Path -Parent $PSCommandPath
    $dossierLogs = Join-Path $dossierScript "Logs"
    if (-not (Test-Path $dossierLogs)) {
        New-Item -Path $dossierLogs -ItemType Directory -Force | Out-Null
    }
    $nomFichier = "hyper-v_$(Get-Date -Format 'yyyy-MM-dd').log"
    return Join-Path $dossierLogs $nomFichier
}

function Ecrire-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Niveau = "INFO"
    )
    $horodatage = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ligne = "[$horodatage] [$Niveau] $Message"
    $cheminLog = Get-CheminLog
    Add-Content -Path $cheminLog -Value $ligne -Encoding UTF8
}

function Tester-PSRemoting {
    param([string]$Serveur)

    Write-Host "Vérification de la connexion PowerShell Remoting vers $Serveur..." -ForegroundColor Yellow
    try {
        $result = Invoke-Command -ComputerName $Serveur -ScriptBlock { $env:COMPUTERNAME } -ErrorAction Stop
        Write-Host "Connexion OK vers $result." -ForegroundColor Green
        Ecrire-Log "PSRemoting OK vers $Serveur (réponse: $result)" "SUCCESS"
        return $true
    }
    catch {
        Write-Host "ERREUR : Impossible de se connecter à  $Serveur via PowerShell Remoting." -ForegroundColor Red
        Write-Host "Vérifiez que :" -ForegroundColor Yellow
        Write-Host "  - WinRM est activé sur $Serveur (Enable-PSRemoting -Force)" -ForegroundColor Yellow
        Write-Host "  - Le pare-feu autorise WinRM (port 5985/5986)" -ForegroundColor Yellow
        Write-Host "  - Les deux serveurs sont dans le même domaine AD" -ForegroundColor Yellow
        Write-Host "  - Vous avez les droits administrateur sur $Serveur" -ForegroundColor Yellow
        Ecrire-Log "PSRemoting ECHEC vers $Serveur : $_" "ERROR"
        return $false
    }
}

function Verifier-Prerequis {
    Write-Host "`n--- Vérification des prérequis ---" -ForegroundColor Cyan
    $ok = $true

    # Vérifier Hyper-V
    $hyperv = Get-WindowsFeature Hyper-V -ErrorAction SilentlyContinue
    if ($null -eq $hyperv -or -not $hyperv.Installed) {
        Write-Host "ERREUR : Le rà´le Hyper-V n'est pas installé !" -ForegroundColor Red
        Ecrire-Log "Prérequis ECHEC : Hyper-V non installé" "ERROR"
        $ok = $false
    }
    else {
        Write-Host "Hyper-V : OK" -ForegroundColor Green
    }

    # Vérifier PSRemoting vers le serveur réplica
    if (-not (Tester-PSRemoting -Serveur $Config.ServeurReplica)) {
        Write-Host "`nATTENTION : Les fonctions de nettoyage distant ne seront pas disponibles." -ForegroundColor Yellow
        Write-Host "La création de VM et la réplication peuvent quand même fonctionner." -ForegroundColor Yellow
        Ecrire-Log "PSRemoting indisponible - fonctions distantes limitées" "WARN"
        $script:PSRemotingOK = $false
    }
    else {
        $script:PSRemotingOK = $true
    }

    return $ok
}

# ============================================================
# FONCTIONS DU MENU
# ============================================================

function Afficher-Menu {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   GESTION DES VM HYPER-V AVEC REPLICATION   " -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Serveur actuel  : $env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host "  Serveur replica : $($Config.ServeurReplica)" -ForegroundColor Gray
    Write-Host "  PSRemoting      : $(if ($script:PSRemotingOK) { 'Connecté' } else { 'Non disponible' })" -ForegroundColor $(if ($script:PSRemotingOK) { 'Green' } else { 'Red' })
    Write-Host ""
    Write-Host "  [1] Créer une VM + activer la réplication" -ForegroundColor Green
    Write-Host "  [2] Lister les VM existantes" -ForegroundColor Yellow
    Write-Host "  [3] Supprimer une VM" -ForegroundColor Red
    Write-Host "  [4] Voir le statut des réplications" -ForegroundColor Magenta
    Write-Host "  [5] Nettoyage des réplicas orphelins" -ForegroundColor DarkYellow
    Write-Host "  [6] Réparer / Activer la réplication d'une VM" -ForegroundColor Blue
    Write-Host "  [Q] Quitter" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
}

function Selectionner-ISO {
    Write-Host "`n--- Sélection de l'ISO ---" -ForegroundColor Cyan

    if (-not (Test-Path $Config.CheminISOs)) {
        Write-Host "ERREUR : Le dossier $($Config.CheminISOs) n'existe pas !" -ForegroundColor Red
        return $null
    }

    $isos = Get-ChildItem -Path $Config.CheminISOs -Filter "*.iso" | Sort-Object Name
    if ($isos.Count -eq 0) {
        Write-Host "ERREUR : Aucun fichier ISO trouvé dans $($Config.CheminISOs)" -ForegroundColor Red
        return $null
    }

    Write-Host "`nFichiers ISO disponibles :" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $isos.Count; $i++) {
        $taille = [math]::Round($isos[$i].Length / 1GB, 2)
        Write-Host "  [$($i + 1)] $($isos[$i].Name) ($taille Go)" -ForegroundColor White
    }
    Write-Host ""

    do {
        $choix = Read-Host "Choisissez un ISO (1-$($isos.Count))"
    } while ($choix -lt 1 -or $choix -gt $isos.Count)

    $isoSelectionnee = $isos[$choix - 1]
    Write-Host "ISO sélectionnée : $($isoSelectionnee.Name)" -ForegroundColor Green
    return $isoSelectionnee.FullName
}

function Configurer-ServicesIntegration {
    param([string]$NomVM)

    Write-Host "`n--- Services d'intégration ---" -ForegroundColor Cyan
    Write-Host "Sélectionnez les services à  activer/désactiver :" -ForegroundColor Yellow
    Write-Host ""

    $services = @(
        @{ Nom = "Arrêt du système d'exploitation";           Cle = "Arrêt";                             Defaut = $true  }
        @{ Nom = "Synchronisation date/heure";                Cle = "Synchronisation date/heure";        Defaut = $true  }
        @{ Nom = "Échange de paires clé-valeur";              Cle = "Échange de paires clé-valeur";      Defaut = $true  }
        @{ Nom = "Pulsation";                                 Cle = "Pulsation";                         Defaut = $true  }
        @{ Nom = "Sauvegarde (cliché instantané de volumes)"; Cle = "VSS";                               Defaut = $true  }
        @{ Nom = "Interface de services d'invité";            Cle = "Interface de services d'invité";    Defaut = $false }
    )

    $choixServices = @{}

    foreach ($service in $services) {
        $defautTxt = if ($service.Defaut) { "O" } else { "N" }
        $defautLabel = if ($service.Defaut) { "activé" } else { "désactivé" }

        do {
            $reponse = Read-Host "  $($service.Nom) [par défaut: $defautLabel] (O/N)"
            if ([string]::IsNullOrWhiteSpace($reponse)) { $reponse = $defautTxt }
        } while ($reponse -ne "O" -and $reponse -ne "o" -and $reponse -ne "N" -and $reponse -ne "n")

        $choixServices[$service.Cle] = ($reponse -eq "O" -or $reponse -eq "o")
    }

    foreach ($cle in $choixServices.Keys) {
        if ($choixServices[$cle]) {
            Enable-VMIntegrationService -VMName $NomVM -Name $cle -ErrorAction SilentlyContinue
        }
        else {
            Disable-VMIntegrationService -VMName $NomVM -Name $cle -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Services d'intégration configurés." -ForegroundColor Green
    Ecrire-Log "Services d'intégration configurés pour '$NomVM'" "INFO"
    return $choixServices
}

function Configurer-ActionArret {
    param([string]$NomVM)

    Write-Host "`n--- Action d'arrêt automatique ---" -ForegroundColor Cyan
    Write-Host "Quelle action lors de l'arrêt de l'hà´te physique ?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Mettre en mémoire l'état de la VM (par défaut)"
    Write-Host "      → La RAM est sauvegardée sur disque, la VM reprend là  où elle en était"
    Write-Host "  [2] Éteindre l'ordinateur virtuel"
    Write-Host "      → Équivalent d'un arrêt brutal (coupure de courant)"
    Write-Host "  [3] Arrêter le système d'exploitation invité"
    Write-Host "      → Arrêt propre via les services d'intégration"
    Write-Host ""

    do {
        $choix = Read-Host "Choix (1, 2 ou 3)"
    } while ($choix -ne "1" -and $choix -ne "2" -and $choix -ne "3")

    $action = switch ($choix) {
        "1" { "Save" }
        "2" { "TurnOff" }
        "3" { "ShutDown" }
    }

    Set-VM -VMName $NomVM -AutomaticStopAction $action

    $actionTxt = switch ($choix) {
        "1" { "Mettre en mémoire l'état" }
        "2" { "Éteindre la VM" }
        "3" { "Arrêter le système invité" }
    }

    Write-Host "Action d'arrêt configurée : $actionTxt" -ForegroundColor Green
    Ecrire-Log "Action d'arrêt pour '$NomVM' : $actionTxt" "INFO"
    return $actionTxt
}

function Creer-VM {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   CREATION D'UNE NOUVELLE VM" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    # --- Nom de la VM ---
    do {
        $nomVM = Read-Host "Nom de la VM"
        if (Get-VM -Name $nomVM -ErrorAction SilentlyContinue) {
            Write-Host "ERREUR : Une VM avec ce nom existe déjà  !" -ForegroundColor Red
            $nomVM = $null
        }
    } while ([string]::IsNullOrWhiteSpace($nomVM))

    # --- Remarque / Notes ---
    Write-Host ""
    $remarque = Read-Host "Remarque sur la VM (laisser vide si aucune)"

    # --- Génération ---
    Write-Host "`nGénération de la VM :" -ForegroundColor Yellow
    Write-Host "  [1] Génération 1 (BIOS - compatibilité legacy)"
    Write-Host "  [2] Génération 2 (UEFI - recommandé pour Windows récent)"
    do {
        $choixGen = Read-Host "Choix (1 ou 2)"
    } while ($choixGen -ne "1" -and $choixGen -ne "2")
    $generation = [int]$choixGen

    # --- Secure Boot (Génération 2 uniquement) ---
    $secureBoot = $false
    if ($generation -eq 2) {
        Write-Host "`nSecure Boot :" -ForegroundColor Yellow
        Write-Host "  [1] Activé (recommandé pour Windows, peut bloquer certaines ISOs)"
        Write-Host "  [2] Désactivé (nécessaire pour Linux ou ISOs non signées)"
        do {
            $choixSB = Read-Host "Choix (1 ou 2)"
        } while ($choixSB -ne "1" -and $choixSB -ne "2")
        $secureBoot = ($choixSB -eq "1")
    }

    # --- Nombre de processeurs virtuels ---
    do {
        $nbCPU = Read-Host "`nNombre de processeurs virtuels (ex: 2, 4, 8)"
        $nbCPU = [int]$nbCPU
    } while ($nbCPU -lt 1 -or $nbCPU -gt 64)

    # --- Mémoire RAM ---
    Write-Host "`nType de mémoire :" -ForegroundColor Yellow
    Write-Host "  [1] Mémoire fixe"
    Write-Host "  [2] Mémoire dynamique (s'ajuste entre un min et un max selon les besoins)"
    do {
        $choixRAM = Read-Host "Choix (1 ou 2)"
    } while ($choixRAM -ne "1" -and $choixRAM -ne "2")

    if ($choixRAM -eq "1") {
        do {
            $ramMB = Read-Host "`nQuantité de RAM en Mo (ex: 2048, 4096, 8192)"
            $ramMB = [int]$ramMB
        } while ($ramMB -lt 512)
        $ramStartup = $ramMB * 1MB
        $dynamique = $false
    }
    else {
        do {
            $ramMinMB = Read-Host "`nRAM minimum en Mo (ex: 512, 1024)"
            $ramMinMB = [int]$ramMinMB
        } while ($ramMinMB -lt 512)

        do {
            $ramStartupMB = Read-Host "RAM au démarrage en Mo (ex: 2048, 4096)"
            $ramStartupMB = [int]$ramStartupMB
        } while ($ramStartupMB -lt $ramMinMB)

        do {
            $ramMaxMB = Read-Host "RAM maximum en Mo (ex: 4096, 8192)"
            $ramMaxMB = [int]$ramMaxMB
        } while ($ramMaxMB -lt $ramStartupMB)

        $ramStartup = $ramStartupMB * 1MB
        $ramMin = $ramMinMB * 1MB
        $ramMax = $ramMaxMB * 1MB
        $dynamique = $true
    }

    # --- Disque dur virtuel ---
    do {
        $disqueGo = Read-Host "`nTaille du disque dur virtuel en Go (ex: 40, 80, 127)"
        $disqueGo = [int]$disqueGo
    } while ($disqueGo -lt 1)
    $tailleDisque = $disqueGo * 1GB

    # --- Réseau ---
    $switches = Get-VMSwitch | Sort-Object Name
    if ($switches.Count -eq 0) {
        Write-Host "ATTENTION : Aucun switch virtuel trouvé ! La VM sera créée sans réseau." -ForegroundColor Yellow
        $switchNom = $null
    }
    elseif ($switches.Count -eq 1) {
        $switchNom = $switches[0].Name
        Write-Host "`nSwitch virtuel détecté : $switchNom" -ForegroundColor Green
    }
    else {
        Write-Host "`nSwitchs virtuels disponibles :" -ForegroundColor Yellow
        for ($i = 0; $i -lt $switches.Count; $i++) {
            Write-Host "  [$($i + 1)] $($switches[$i].Name) ($($switches[$i].SwitchType))"
        }
        do {
            $choixSwitch = Read-Host "Choisissez un switch (1-$($switches.Count))"
        } while ($choixSwitch -lt 1 -or $choixSwitch -gt $switches.Count)
        $switchNom = $switches[$choixSwitch - 1].Name
    }

    # --- ISO ---
    $cheminISO = Selectionner-ISO
    if ($null -eq $cheminISO) {
        Write-Host "Création annulée." -ForegroundColor Red
        return
    }

    # --- Résumé ---
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   RECAPITULATIF" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  Nom             : $nomVM"
    if (-not [string]::IsNullOrWhiteSpace($remarque)) {
        Write-Host "  Remarque        : $remarque"
    }
    Write-Host "  Génération      : $generation"
    if ($generation -eq 2) {
        $sbTxt = if ($secureBoot) { "Activé" } else { "Désactivé" }
        Write-Host "  Secure Boot     : $sbTxt"
    }
    Write-Host "  Processeurs     : $nbCPU vCPU"
    if ($dynamique) {
        Write-Host "  RAM             : Dynamique ($ramMinMB Mo / $ramStartupMB Mo / $ramMaxMB Mo)"
    } else {
        Write-Host "  RAM             : Fixe ($ramMB Mo)"
    }
    Write-Host "  Disque          : $disqueGo Go"
    Write-Host "  Switch          : $switchNom"
    Write-Host "  ISO             : $(Split-Path $cheminISO -Leaf)"
    Write-Host "  Réplication vers: $($Config.ServeurReplica)"
    Write-Host "==============================================`n" -ForegroundColor Cyan

    $confirmation = Read-Host "Confirmer la création ? (O/N)"
    if ($confirmation -ne "O" -and $confirmation -ne "o") {
        Write-Host "Création annulée." -ForegroundColor Yellow
        Ecrire-Log "Création de '$nomVM' annulée par l'utilisateur" "INFO"
        return
    }

    # --- Création des dossiers ---
    $cheminVM = Join-Path $Config.CheminVMs $nomVM
    $cheminVHDX = Join-Path $cheminVM "Virtual Hard Disks"
    New-Item -Path $cheminVHDX -ItemType Directory -Force | Out-Null

    # --- Création de la VM ---
    try {
        Write-Host "`nCréation de la VM en cours..." -ForegroundColor Yellow
        Ecrire-Log "Début de la création de la VM '$nomVM'" "INFO"

        $params = @{
            Name               = $nomVM
            Generation         = $generation
            MemoryStartupBytes = $ramStartup
            Path               = $Config.CheminVMs
            NewVHDPath         = Join-Path $cheminVHDX "$nomVM.vhdx"
            NewVHDSizeBytes    = $tailleDisque
        }

        if ($switchNom) {
            $params.SwitchName = $switchNom
        }

        New-VM @params | Out-Null
        Write-Host "VM créée avec succès." -ForegroundColor Green

        # Remarque
        if (-not [string]::IsNullOrWhiteSpace($remarque)) {
            Set-VM -VMName $nomVM -Notes $remarque
            Write-Host "Remarque ajoutée." -ForegroundColor Green
        }

        # Processeurs
        Set-VMProcessor -VMName $nomVM -Count $nbCPU
        Write-Host "Processeurs configurés : $nbCPU vCPU" -ForegroundColor Green

        # Mémoire dynamique
        if ($dynamique) {
            Set-VMMemory -VMName $nomVM -DynamicMemoryEnabled $true `
                -MinimumBytes $ramMin -StartupBytes $ramStartup -MaximumBytes $ramMax
            Write-Host "Mémoire dynamique configurée." -ForegroundColor Green
        }

        # Montage ISO et ordre de boot
        if ($generation -eq 2) {
            if ($secureBoot) {
                Set-VMFirmware -VMName $nomVM -EnableSecureBoot On
                Write-Host "Secure Boot activé." -ForegroundColor Green
            }
            else {
                Set-VMFirmware -VMName $nomVM -EnableSecureBoot Off
                Write-Host "Secure Boot désactivé." -ForegroundColor Yellow
            }

            $disqueActuel = Get-VMHardDiskDrive -VMName $nomVM
            Remove-VMHardDiskDrive -VMName $nomVM -ControllerType SCSI -ControllerNumber $disqueActuel.ControllerNumber -ControllerLocation $disqueActuel.ControllerLocation
            Add-VMHardDiskDrive -VMName $nomVM -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 1 -Path $disqueActuel.Path

            Add-VMDvdDrive -VMName $nomVM -ControllerNumber 0 -ControllerLocation 0 -Path $cheminISO
            $dvd = Get-VMDvdDrive -VMName $nomVM

            Set-VMFirmware -VMName $nomVM -FirstBootDevice $dvd
            Write-Host "Ordre de boot : DVD (ISO) en (0,0), disque en (0,1)." -ForegroundColor Green
        }
        else {
            Set-VMDvdDrive -VMName $nomVM -Path $cheminISO
            Set-VMBios -VMName $nomVM -StartupOrder @("CD", "IDE", "LegacyNetworkAdapter", "Floppy")
            Write-Host "Ordre de boot : CD (ISO) en premier." -ForegroundColor Green
        }
        Write-Host "ISO montée : $(Split-Path $cheminISO -Leaf)" -ForegroundColor Green

        # Désactiver les checkpoints automatiques
        Set-VM -VMName $nomVM -AutomaticCheckpointsEnabled $false
        Write-Host "Checkpoints automatiques désactivés." -ForegroundColor Green

        # Services d'intégration
        Configurer-ServicesIntegration -NomVM $nomVM

        # Action d'arrêt automatique
        Configurer-ActionArret -NomVM $nomVM

        # Activer la réplication
        Write-Host "`nActivation de la réplication vers $($Config.ServeurReplica)..." -ForegroundColor Yellow

        Enable-VMReplication -VMName $nomVM `
            -ReplicaServerName $Config.ServeurReplica `
            -ReplicaServerPort $Config.PortReplication `
            -AuthenticationType $Config.AuthReplication `
            -CompressionEnabled $Config.CompressionReplication `
            -ReplicationFrequencySec $Config.FrequenceReplication

        Start-VMInitialReplication -VMName $nomVM

        Write-Host "Réplication activée et synchronisation initiale lancée." -ForegroundColor Green
        Write-Host "`nVM '$nomVM' prête ! Vous pouvez la démarrer." -ForegroundColor Green
        Ecrire-Log "VM '$nomVM' créée avec succès (Gen$generation, ${nbCPU}vCPU, réplication vers $($Config.ServeurReplica))" "SUCCESS"
    }
    catch {
        Write-Host "ERREUR lors de la création : $_" -ForegroundColor Red
        Ecrire-Log "ERREUR création VM '$nomVM' : $_" "ERROR"
    }
}

function Lister-VMs {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   LISTE DES VM" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    $vms = Get-VM | Sort-Object Name

    if ($vms.Count -eq 0) {
        Write-Host "Aucune VM trouvée sur ce serveur." -ForegroundColor Yellow
        return
    }

    foreach ($vm in $vms) {
        $etat = switch ($vm.State) {
            "Running"  { "En marche" }
            "Off"      { "Éteinte" }
            "Saved"    { "Sauvegardée" }
            "Paused"   { "En pause" }
            default    { $vm.State }
        }

        $couleurEtat = switch ($vm.State) {
            "Running" { "Green" }
            "Off"     { "Red" }
            "Saved"   { "Yellow" }
            "Paused"  { "Yellow" }
            default   { "White" }
        }

        $ramMo = [math]::Round($vm.MemoryAssigned / 1MB)

        try {
            $repli = Get-VMReplication -VMName $vm.Name -ErrorAction SilentlyContinue
            $statutRepli = if ($repli) { $repli.State } else { "Non configurée" }
        }
        catch {
            $statutRepli = "Non configurée"
        }

        $actionArret = switch ($vm.AutomaticStopAction) {
            "Save"     { "Mettre en mémoire" }
            "TurnOff"  { "Éteindre" }
            "ShutDown" { "Arrêt système invité" }
            default    { $vm.AutomaticStopAction }
        }

        Write-Host "  -----------------------------------------------" -ForegroundColor Gray
        Write-Host "  VM : $($vm.Name)" -ForegroundColor White
        Write-Host "    État            : $etat" -ForegroundColor $couleurEtat
        Write-Host "    Processeurs     : $($vm.ProcessorCount) vCPU"
        Write-Host "    RAM assignée    : $ramMo Mo"
        Write-Host "    Réplication     : $statutRepli"
        Write-Host "    Action d'arrêt  : $actionArret"

        if (-not [string]::IsNullOrWhiteSpace($vm.Notes)) {
            Write-Host "    Remarque        : $($vm.Notes)" -ForegroundColor DarkYellow
        }
    }

    Write-Host "  -----------------------------------------------" -ForegroundColor Gray
    Write-Host "`nTotal : $($vms.Count) VM(s)" -ForegroundColor Cyan
}

function Nettoyer-ReplicaDistant {
    param(
        [string]$NomVM,
        [switch]$DemandeSuppression
    )

    if (-not $script:PSRemotingOK) {
        Write-Host "PSRemoting non disponible. Impossible de nettoyer le serveur distant." -ForegroundColor Red
        Write-Host "Connectez-vous manuellement à  $($Config.ServeurReplica) pour nettoyer." -ForegroundColor Yellow
        Ecrire-Log "Nettoyage distant impossible pour '$NomVM' : PSRemoting indisponible" "WARN"
        return
    }

    $serveur = $Config.ServeurReplica
    $cheminReplicas = $Config.CheminReplicas

    # Vérifier ce qui existe sur le serveur distant
    $infoDistante = Invoke-Command -ComputerName $serveur -ScriptBlock {
        param($nomVM, $cheminReplicas)
        $result = @{
            VMExiste      = $false
            DossierExiste = $false
            CheminDossier = ""
        }

        # Vérifier si la VM fantôme existe dans Hyper-V
        $vm = Get-VM -Name $nomVM -ErrorAction SilentlyContinue
        if ($vm) { $result.VMExiste = $true }

        # Vérifier si le dossier de réplication existe
        $dossier = Join-Path $cheminReplicas $nomVM
        if (Test-Path $dossier) {
            $result.DossierExiste = $true
            $result.CheminDossier = $dossier
        }

        return $result
    } -ArgumentList $NomVM, $cheminReplicas

    if (-not $infoDistante.VMExiste -and -not $infoDistante.DossierExiste) {
        Write-Host "Rien à  nettoyer sur $serveur pour '$NomVM'." -ForegroundColor Green
        Ecrire-Log "Nettoyage distant '$NomVM' : rien trouvé sur $serveur" "INFO"
        return
    }

    Write-Host "`n--- Nettoyage sur $serveur pour '$NomVM' ---" -ForegroundColor Cyan
    if ($infoDistante.VMExiste) {
        Write-Host "  VM fantôme trouvée dans Hyper-V sur $serveur" -ForegroundColor Yellow
    }
    if ($infoDistante.DossierExiste) {
        Write-Host "  Dossier réplica trouvé : $($infoDistante.CheminDossier)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  [1] Supprimer uniquement les fichiers réplica (dossier)" -ForegroundColor White
    Write-Host "  [2] Supprimer uniquement la VM fantôme (Hyper-V)" -ForegroundColor White
    Write-Host "  [3] Supprimer les deux (fichiers + VM fantôme)" -ForegroundColor White
    Write-Host "  [0] Ne rien faire" -ForegroundColor Gray
    Write-Host ""

    do {
        $choix = Read-Host "Choix (0, 1, 2 ou 3)"
    } while ($choix -ne "0" -and $choix -ne "1" -and $choix -ne "2" -and $choix -ne "3")

    if ($choix -eq "0") {
        Write-Host "Aucune action sur le serveur distant." -ForegroundColor Yellow
        Ecrire-Log "Nettoyage distant '$NomVM' : annulé par l'utilisateur" "INFO"
        return
    }

    # Confirmation par nom exact
    Write-Host ""
    $confirmation = Read-Host "Tapez le nom exact de la VM pour confirmer la suppression distante"
    if ($confirmation -ne $NomVM) {
        Write-Host "Le nom ne correspond pas. Nettoyage distant annulé." -ForegroundColor Yellow
        Ecrire-Log "Nettoyage distant '$NomVM' : confirmation échouée" "WARN"
        return
    }

    $supprimerFichiers = ($choix -eq "1" -or $choix -eq "3")
    $supprimerVM = ($choix -eq "2" -or $choix -eq "3")

    try {
        Invoke-Command -ComputerName $serveur -ScriptBlock {
            param($nomVM, $cheminReplicas, $supprimerVM, $supprimerFichiers)

            if ($supprimerVM) {
                $vm = Get-VM -Name $nomVM -ErrorAction SilentlyContinue
                if ($vm) {
                    # Supprimer la réplication sur la VM réplica si elle existe
                    $repli = Get-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                    if ($repli) {
                        Remove-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                    }

                    # Arrêter la VM si elle tourne
                    if ($vm.State -eq "Running") {
                        Stop-VM -Name $nomVM -Force -ErrorAction SilentlyContinue
                    }

                    Remove-VM -Name $nomVM -Force
                }
            }

            if ($supprimerFichiers) {
                $dossier = Join-Path $cheminReplicas $nomVM
                if (Test-Path $dossier) {
                    Remove-Item -Path $dossier -Recurse -Force
                }
            }
        } -ArgumentList $NomVM, $cheminReplicas, $supprimerVM, $supprimerFichiers

        if ($supprimerVM -and $supprimerFichiers) {
            Write-Host "VM fantôme et fichiers réplica supprimés sur $serveur." -ForegroundColor Green
            Ecrire-Log "Nettoyage distant '$NomVM' : VM + fichiers supprimés sur $serveur" "SUCCESS"
        }
        elseif ($supprimerVM) {
            Write-Host "VM fantôme supprimée sur $serveur." -ForegroundColor Green
            Ecrire-Log "Nettoyage distant '$NomVM' : VM supprimée sur $serveur" "SUCCESS"
        }
        elseif ($supprimerFichiers) {
            Write-Host "Fichiers réplica supprimés sur $serveur." -ForegroundColor Green
            Ecrire-Log "Nettoyage distant '$NomVM' : fichiers supprimés sur $serveur" "SUCCESS"
        }
    }
    catch {
        Write-Host "ERREUR lors du nettoyage distant : $_" -ForegroundColor Red
        Ecrire-Log "ERREUR nettoyage distant '$NomVM' sur $serveur : $_" "ERROR"
    }
}

function Supprimer-VM {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   SUPPRESSION D'UNE VM" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    $vms = Get-VM | Sort-Object Name

    if ($vms.Count -eq 0) {
        Write-Host "Aucune VM trouvée sur ce serveur." -ForegroundColor Yellow
        return
    }

    for ($i = 0; $i -lt $vms.Count; $i++) {
        $etat = switch ($vms[$i].State) {
            "Running"  { "En marche" }
            "Off"      { "Éteinte" }
            default    { $vms[$i].State }
        }
        $note = if (-not [string]::IsNullOrWhiteSpace($vms[$i].Notes)) { " - $($vms[$i].Notes)" } else { "" }
        Write-Host "  [$($i + 1)] $($vms[$i].Name) ($etat)$note"
    }
    Write-Host "  [0] Annuler"
    Write-Host ""

    do {
        $choix = Read-Host "Quelle VM supprimer ? (0-$($vms.Count))"
        $choix = [int]$choix
    } while ($choix -lt 0 -or $choix -gt $vms.Count)

    if ($choix -eq 0) {
        Write-Host "Suppression annulée." -ForegroundColor Yellow
        return
    }

    $vmASupprimer = $vms[$choix - 1]

    Write-Host "`nATTENTION : Vous allez supprimer '$($vmASupprimer.Name)' !" -ForegroundColor Red
    Write-Host "Cela supprimera la VM, ses disques VHDX et sa réplication locale." -ForegroundColor Red
    $confirmation = Read-Host "Tapez le nom exact de la VM pour confirmer"

    if ($confirmation -ne $vmASupprimer.Name) {
        Write-Host "Le nom ne correspond pas. Suppression annulée." -ForegroundColor Yellow
        return
    }

    try {
        Ecrire-Log "Début de la suppression de la VM '$($vmASupprimer.Name)'" "INFO"

        # Arrêter la VM si elle tourne
        if ($vmASupprimer.State -eq "Running") {
            Write-Host "Arrêt de la VM..." -ForegroundColor Yellow
            Stop-VM -Name $vmASupprimer.Name -Force
        }

        # Supprimer la réplication locale si active
        $repli = Get-VMReplication -VMName $vmASupprimer.Name -ErrorAction SilentlyContinue
        if ($repli) {
            Write-Host "Suppression de la réplication locale..." -ForegroundColor Yellow
            Remove-VMReplication -VMName $vmASupprimer.Name
        }

        # Récupérer les chemins des VHDX
        $disques = Get-VMHardDiskDrive -VMName $vmASupprimer.Name

        # Supprimer la VM
        Write-Host "Suppression de la VM locale..." -ForegroundColor Yellow
        Remove-VM -Name $vmASupprimer.Name -Force

        # Supprimer les fichiers VHDX
        foreach ($disque in $disques) {
            if (Test-Path $disque.Path) {
                Remove-Item -Path $disque.Path -Force
                Write-Host "Disque supprimé : $($disque.Path)" -ForegroundColor Gray
            }
        }

        # Supprimer le dossier de la VM
        $dossierVM = Join-Path $Config.CheminVMs $vmASupprimer.Name
        if (Test-Path $dossierVM) {
            Remove-Item -Path $dossierVM -Recurse -Force
            Write-Host "Dossier supprimé : $dossierVM" -ForegroundColor Gray
        }

        Write-Host "`nVM '$($vmASupprimer.Name)' supprimée localement." -ForegroundColor Green
        Ecrire-Log "VM '$($vmASupprimer.Name)' supprimée localement avec succès" "SUCCESS"

        # Proposer le nettoyage sur le serveur distant
        Write-Host "`nVoulez-vous nettoyer les réplicas sur $($Config.ServeurReplica) ?" -ForegroundColor Cyan
        $choixNettoyage = Read-Host "(O/N)"
        if ($choixNettoyage -eq "O" -or $choixNettoyage -eq "o") {
            Nettoyer-ReplicaDistant -NomVM $vmASupprimer.Name
        }
        else {
            Write-Host "Le dossier réplica sur $($Config.ServeurReplica) n'a pas été modifié." -ForegroundColor Yellow
            Ecrire-Log "Nettoyage distant pour '$($vmASupprimer.Name)' : refusé par l'utilisateur" "INFO"
        }
    }
    catch {
        Write-Host "ERREUR lors de la suppression : $_" -ForegroundColor Red
        Ecrire-Log "ERREUR suppression VM '$($vmASupprimer.Name)' : $_" "ERROR"
    }
}

function Voir-StatutReplications {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   STATUT DES REPLICATIONS" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    $replications = Get-VMReplication -ErrorAction SilentlyContinue

    if ($null -eq $replications -or $replications.Count -eq 0) {
        Write-Host "Aucune réplication configurée sur ce serveur." -ForegroundColor Yellow
        return
    }

    foreach ($repli in $replications) {
        $etat = switch ($repli.State) {
            "Replicating"                    { "En cours" }
            "ReadyForInitialReplication"      { "En attente de synchro initiale" }
            "WaitingForInitialReplication"    { "Attente synchro initiale" }
            "Suspended"                      { "Suspendue" }
            "Error"                          { "Erreur" }
            "FailedOver"                     { "Basculée" }
            default                          { $repli.State }
        }

        $sante = switch ($repli.Health) {
            "Normal"   { "OK" }
            "Warning"  { "Attention" }
            "Critical" { "Critique" }
            default    { $repli.Health }
        }

        $couleur = switch ($repli.Health) {
            "Normal"   { "Green" }
            "Warning"  { "Yellow" }
            "Critical" { "Red" }
            default    { "White" }
        }

        Write-Host "  VM : $($repli.VMName)" -ForegroundColor White
        Write-Host "    État           : $etat" -ForegroundColor $couleur
        Write-Host "    Santé          : $sante" -ForegroundColor $couleur
        Write-Host "    Serveur cible  : $($repli.ReplicaServerName)"
        Write-Host "    Fréquence      : $($repli.FrequencySec) secondes"
        Write-Host "    Mode           : $($repli.ReplicationMode)"

        if ($repli.LastReplicationTime) {
            Write-Host "    Dernière synchro: $($repli.LastReplicationTime)"
        }
        Write-Host ""
    }
}

function Nettoyer-ReplicasOrphelins {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   NETTOYAGE DES REPLICAS ORPHELINS" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    if (-not $script:PSRemotingOK) {
        Write-Host "PSRemoting non disponible. Impossible de scanner le serveur distant." -ForegroundColor Red
        Write-Host "Vérifiez la connectivité vers $($Config.ServeurReplica)." -ForegroundColor Yellow
        Ecrire-Log "Nettoyage orphelins : PSRemoting indisponible" "ERROR"
        return
    }

    $serveur = $Config.ServeurReplica
    $cheminReplicas = $Config.CheminReplicas

    Write-Host "Analyse en cours..." -ForegroundColor Yellow
    Write-Host "  Serveur local  : $env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host "  Serveur distant: $serveur" -ForegroundColor Gray
    Write-Host ""

    # Récupérer les noms des VM locales
    $vmsLocales = @(Get-VM | Select-Object -ExpandProperty Name)

    # Récupérer les dossiers dans D:\Replicas sur le serveur distant
    $infoDistante = Invoke-Command -ComputerName $serveur -ScriptBlock {
        param($cheminReplicas)
        $result = @{
            Dossiers = @()
            VMs      = @()
        }

        # Lister les dossiers dans le répertoire de réplication
        if (Test-Path $cheminReplicas) {
            $result.Dossiers = (Get-ChildItem -Path $cheminReplicas -Directory | Select-Object -ExpandProperty Name)
        }

        # Lister les VM enregistrées dans Hyper-V
        $result.VMs = (Get-VM | Select-Object -ExpandProperty Name)

        return $result
    } -ArgumentList $cheminReplicas

    $dossiersDistants = $infoDistante.Dossiers
    $vmsDistantes = $infoDistante.VMs

    # Trouver les orphelins : dossiers dans D:\Replicas qui n'ont pas de VM correspondante localement
    $orphelins = @()
    foreach ($dossier in $dossiersDistants) {
        if ($dossier -notin $vmsLocales) {
            $vmFantome = $dossier -in $vmsDistantes
            $orphelins += [PSCustomObject]@{
                Nom        = $dossier
                VMFantome  = $vmFantome
            }
        }
    }

    if ($orphelins.Count -eq 0) {
        Write-Host "Aucun réplica orphelin détecté. Tout est propre !" -ForegroundColor Green
        Ecrire-Log "Nettoyage orphelins : aucun orphelin détecté" "INFO"
        return
    }

    Write-Host "Réplicas orphelins détectés ($($orphelins.Count)) :" -ForegroundColor Yellow
    Write-Host ""

    foreach ($orphelin in $orphelins) {
        $vmInfo = if ($orphelin.VMFantome) { " + VM fantôme dans Hyper-V" } else { "" }
        Write-Host "  - $($orphelin.Nom) (dossier dans $cheminReplicas$vmInfo)" -ForegroundColor White
    }

    Write-Host ""
    Ecrire-Log "Nettoyage orphelins : $($orphelins.Count) orphelin(s) détecté(s) : $($orphelins.Nom -join ', ')" "INFO"

    # Traiter chaque orphelin un par un
    foreach ($orphelin in $orphelins) {
        Write-Host "`n--- $($orphelin.Nom) ---" -ForegroundColor Cyan

        if ($orphelin.VMFantome) {
            Write-Host "  Dossier réplica ET VM fantôme trouvés sur $serveur" -ForegroundColor Yellow
        }
        else {
            Write-Host "  Dossier réplica trouvé sur $serveur (pas de VM fantôme)" -ForegroundColor Yellow
        }

        Write-Host ""
        if ($orphelin.VMFantome) {
            Write-Host "  [1] Supprimer uniquement les fichiers réplica (dossier)" -ForegroundColor White
            Write-Host "  [2] Supprimer uniquement la VM fantôme (Hyper-V)" -ForegroundColor White
            Write-Host "  [3] Supprimer les deux (fichiers + VM fantôme)" -ForegroundColor White
        }
        else {
            Write-Host "  [1] Supprimer les fichiers réplica (dossier)" -ForegroundColor White
        }
        Write-Host "  [0] Ignorer / Suivant" -ForegroundColor Gray
        Write-Host ""

        if ($orphelin.VMFantome) {
            do {
                $choix = Read-Host "Choix (0, 1, 2 ou 3)"
            } while ($choix -ne "0" -and $choix -ne "1" -and $choix -ne "2" -and $choix -ne "3")
        }
        else {
            do {
                $choix = Read-Host "Choix (0 ou 1)"
            } while ($choix -ne "0" -and $choix -ne "1")
        }

        if ($choix -eq "0") {
            Write-Host "  Ignoré." -ForegroundColor Gray
            Ecrire-Log "Orphelin '$($orphelin.Nom)' ignoré par l'utilisateur" "INFO"
            continue
        }

        # Confirmation par nom exact
        $confirmation = Read-Host "Tapez le nom exact pour confirmer : '$($orphelin.Nom)'"
        if ($confirmation -ne $orphelin.Nom) {
            Write-Host "  Le nom ne correspond pas. Ignoré." -ForegroundColor Yellow
            Ecrire-Log "Orphelin '$($orphelin.Nom)' : confirmation échouée" "WARN"
            continue
        }

        $supprimerFichiers = ($choix -eq "1" -or $choix -eq "3")
        $supprimerVM = ($choix -eq "2" -or $choix -eq "3")

        try {
            Invoke-Command -ComputerName $serveur -ScriptBlock {
                param($nomVM, $cheminReplicas, $supprimerVM, $supprimerFichiers)

                if ($supprimerVM) {
                    $vm = Get-VM -Name $nomVM -ErrorAction SilentlyContinue
                    if ($vm) {
                        $repli = Get-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                        if ($repli) {
                            Remove-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                        }
                        if ($vm.State -eq "Running") {
                            Stop-VM -Name $nomVM -Force -ErrorAction SilentlyContinue
                        }
                        Remove-VM -Name $nomVM -Force
                    }
                }

                if ($supprimerFichiers) {
                    $dossier = Join-Path $cheminReplicas $nomVM
                    if (Test-Path $dossier) {
                        Remove-Item -Path $dossier -Recurse -Force
                    }
                }
            } -ArgumentList $orphelin.Nom, $cheminReplicas, $supprimerVM, $supprimerFichiers

            $actionTxt = switch ($choix) {
                "1" { "fichiers supprimés" }
                "2" { "VM fantôme supprimée" }
                "3" { "fichiers + VM fantôme supprimés" }
            }
            Write-Host "  $($orphelin.Nom) : $actionTxt sur $serveur." -ForegroundColor Green
            Ecrire-Log "Orphelin '$($orphelin.Nom)' nettoyé sur $serveur : $actionTxt" "SUCCESS"
        }
        catch {
            Write-Host "  ERREUR pour '$($orphelin.Nom)' : $_" -ForegroundColor Red
            Ecrire-Log "ERREUR nettoyage orphelin '$($orphelin.Nom)' : $_" "ERROR"
        }
    }

    Write-Host "`nNettoyage terminé." -ForegroundColor Green
}

function Reparer-Replication {
    Write-Host "`n==============================================" -ForegroundColor Cyan
    Write-Host "   REPARATION / ACTIVATION DE LA REPLICATION" -ForegroundColor Cyan
    Write-Host "==============================================`n" -ForegroundColor Cyan

    $vms = Get-VM | Sort-Object Name

    if ($vms.Count -eq 0) {
        Write-Host "Aucune VM trouvée sur ce serveur." -ForegroundColor Yellow
        return
    }

    # Détecter les VM sans réplication ou avec réplication en erreur
    $vmsAReparer = @()
    foreach ($vm in $vms) {
        $repli = Get-VMReplication -VMName $vm.Name -ErrorAction SilentlyContinue
        if ($null -eq $repli) {
            $vmsAReparer += [PSCustomObject]@{
                Nom    = $vm.Name
                Statut = "Aucune réplication"
                Type   = "Nouvelle"
            }
        }
        elseif ($repli.Health -eq "Critical" -or $repli.Health -eq "Warning" -or $repli.State -eq "Error" -or $repli.State -eq "Suspended") {
            $etatTxt = switch ($repli.State) {
                "Error"     { "Erreur" }
                "Suspended" { "Suspendue" }
                default     { $repli.State }
            }
            $santeTxt = switch ($repli.Health) {
                "Critical" { "Critique" }
                "Warning"  { "Attention" }
                default    { $repli.Health }
            }
            $vmsAReparer += [PSCustomObject]@{
                Nom    = $vm.Name
                Statut = "état: $etatTxt / Santé: $santeTxt"
                Type   = "Réparation"
            }
        }
    }

    if ($vmsAReparer.Count -eq 0) {
        Write-Host "Toutes les VM ont une réplication fonctionnelle." -ForegroundColor Green
        Ecrire-Log "Réparation réplication : aucune VM é réparer" "INFO"
        return
    }

    Write-Host "VM nécessitant une intervention ($($vmsAReparer.Count)) :" -ForegroundColor Yellow
    Write-Host ""
    for ($i = 0; $i -lt $vmsAReparer.Count; $i++) {
        $typeCouleur = if ($vmsAReparer[$i].Type -eq "Nouvelle") { "Cyan" } else { "Red" }
        Write-Host "  [$($i + 1)] $($vmsAReparer[$i].Nom)" -ForegroundColor White -NoNewline
        Write-Host " - $($vmsAReparer[$i].Statut)" -ForegroundColor $typeCouleur -NoNewline
        Write-Host " [$($vmsAReparer[$i].Type)]" -ForegroundColor Gray
    }
    Write-Host ""

    # Traiter chaque VM une par une
    foreach ($vmReparer in $vmsAReparer) {
        Write-Host "`n--- $($vmReparer.Nom) ---" -ForegroundColor Cyan
        Write-Host "  Statut actuel : $($vmReparer.Statut)" -ForegroundColor Yellow
        Write-Host "  Action        : $($vmReparer.Type)" -ForegroundColor Yellow
        Write-Host ""

        if ($vmReparer.Type -eq "Réparation") {
            Write-Host "  Cette opération va :" -ForegroundColor Yellow
            Write-Host "    1. Supprimer la réplication locale existante" -ForegroundColor White
            Write-Host "    2. Nettoyer la VM fantôme et les fichiers sur $($Config.ServeurReplica)" -ForegroundColor White
            Write-Host "    3. Recréer la réplication depuis zéro" -ForegroundColor White
        }
        else {
            Write-Host "  Cette opération va :" -ForegroundColor Yellow
            Write-Host "    1. Activer la réplication vers $($Config.ServeurReplica)" -ForegroundColor White
            Write-Host "    2. Lancer la synchronisation initiale" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "  [1] Procéder" -ForegroundColor Green
        Write-Host "  [0] Ignorer / Suivant" -ForegroundColor Gray
        Write-Host ""

        do {
            $choix = Read-Host "Choix (0 ou 1)"
        } while ($choix -ne "0" -and $choix -ne "1")

        if ($choix -eq "0") {
            Write-Host "  Ignoré." -ForegroundColor Gray
            Ecrire-Log "Réparation réplication '$($vmReparer.Nom)' : ignorée" "INFO"
            continue
        }

        # Confirmation par nom exact
        $confirmation = Read-Host "Tapez le nom exact de la VM pour confirmer"
        if ($confirmation -ne $vmReparer.Nom) {
            Write-Host "  Le nom ne correspond pas. Ignoré." -ForegroundColor Yellow
            Ecrire-Log "Réparation réplication '$($vmReparer.Nom)' : confirmation échouée" "WARN"
            continue
        }

        try {
            Ecrire-Log "Début réparation réplication pour '$($vmReparer.Nom)'" "INFO"

            # Étape 1 : Supprimer la réplication locale existante (si réparation)
            if ($vmReparer.Type -eq "Réparation") {
                Write-Host "  Suppression de la réplication locale..." -ForegroundColor Yellow
                Remove-VMReplication -VMName $vmReparer.Nom -ErrorAction SilentlyContinue
                Write-Host "  Réplication locale supprimée." -ForegroundColor Green

                # Étape 2 : Nettoyer le serveur distant
                if ($script:PSRemotingOK) {
                    Write-Host "  Nettoyage sur $($Config.ServeurReplica)..." -ForegroundColor Yellow
                    $serveur = $Config.ServeurReplica
                    $cheminReplicas = $Config.CheminReplicas
                    $nomVM = $vmReparer.Nom

                    Invoke-Command -ComputerName $serveur -ScriptBlock {
                        param($nomVM, $cheminReplicas)

                        # Supprimer la VM fantôme si elle existe
                        $vm = Get-VM -Name $nomVM -ErrorAction SilentlyContinue
                        if ($vm) {
                            $repli = Get-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                            if ($repli) {
                                Remove-VMReplication -VMName $nomVM -ErrorAction SilentlyContinue
                            }
                            if ($vm.State -eq "Running") {
                                Stop-VM -Name $nomVM -Force -ErrorAction SilentlyContinue
                            }
                            Remove-VM -Name $nomVM -Force
                        }

                        # Supprimer le dossier réplica
                        $dossier = Join-Path $cheminReplicas $nomVM
                        if (Test-Path $dossier) {
                            Remove-Item -Path $dossier -Recurse -Force
                        }
                    } -ArgumentList $nomVM, $cheminReplicas

                    Write-Host "  Serveur distant nettoyé." -ForegroundColor Green
                }
                else {
                    Write-Host "  ATTENTION : PSRemoting indisponible, nettoyage distant impossible." -ForegroundColor Red
                    Write-Host "  Nettoyez manuellement $($Config.ServeurReplica) avant de continuer." -ForegroundColor Yellow
                    Write-Host "  La réplication va quand même être recréée (peut échouer si les anciens fichiers existent)." -ForegroundColor Yellow
                }
            }

            # Étape 3 : (Re)créer la réplication
            Write-Host "  Activation de la réplication vers $($Config.ServeurReplica)..." -ForegroundColor Yellow

            Enable-VMReplication -VMName $vmReparer.Nom `
                -ReplicaServerName $Config.ServeurReplica `
                -ReplicaServerPort $Config.PortReplication `
                -AuthenticationType $Config.AuthReplication `
                -CompressionEnabled $Config.CompressionReplication `
                -ReplicationFrequencySec $Config.FrequenceReplication

            Start-VMInitialReplication -VMName $vmReparer.Nom

            Write-Host "  Réplication activée et synchronisation initiale lancée." -ForegroundColor Green
            Ecrire-Log "Réplication '$($vmReparer.Nom)' : $($vmReparer.Type) réussie" "SUCCESS"
        }
        catch {
            Write-Host "  ERREUR : $_" -ForegroundColor Red
            Ecrire-Log "ERREUR réparation réplication '$($vmReparer.Nom)' : $_" "ERROR"
        }
    }

    Write-Host "`nRéparation terminée." -ForegroundColor Green
}

# ============================================================
# BOUCLE PRINCIPALE
# ============================================================

# Vérification des prérequis
if (-not (Verifier-Prerequis)) {
    Write-Host "`nImpossible de continuer. Corrigez les erreurs ci-dessus." -ForegroundColor Red
    Ecrire-Log "Script arrêté : prérequis non remplis" "ERROR"
    exit
}

Ecrire-Log "Script démarré sur $env:COMPUTERNAME (réplica: $($Config.ServeurReplica))" "INFO"

# Créer les dossiers si nécessaire
if (-not (Test-Path $Config.CheminVMs)) { New-Item -Path $Config.CheminVMs -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $Config.CheminReplicas)) { New-Item -Path $Config.CheminReplicas -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $Config.CheminISOs)) { New-Item -Path $Config.CheminISOs -ItemType Directory -Force | Out-Null }

do {
    Afficher-Menu
    $choix = Read-Host "Votre choix"

    switch ($choix) {
        "1" { Creer-VM }
        "2" { Lister-VMs }
        "3" { Supprimer-VM }
        "4" { Voir-StatutReplications }
        "5" { Nettoyer-ReplicasOrphelins }
        "6" { Reparer-Replication }
        "Q" { break }
        "q" { break }
        default { Write-Host "Choix invalide." -ForegroundColor Red }
    }

    if ($choix -ne "Q" -and $choix -ne "q") {
        Write-Host ""
        Read-Host "Appuyez sur Entrée pour revenir au menu"
    }
} while ($choix -ne "Q" -and $choix -ne "q")

Ecrire-Log "Script terminé" "INFO"
Write-Host "`nAu revoir !" -ForegroundColor Cyan
