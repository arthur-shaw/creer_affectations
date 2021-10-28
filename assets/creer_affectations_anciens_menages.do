/*=============================================================================
PARAMÈTRES DU PROJET
=============================================================================*/

* DOSSIERS
local proj_dir      ""    // où trouver la "racine" du projet
local input_dir     ""    // où trouver les fichiers d'entree. Par exemple: "`proj_dir'/entree/"
local output_dir    ""    // où trouver les fichiers de sortie. Par example: "`proj_dir'/sortie/"

* FICHIERS
* entrée:
local hhold_file_in     "menage.dta"    // fichier ménage
local member_file_in    "membres.dta"   // fichier membre

    * NB: le nom des bases peut être différer d'un contexte à l'autre. Par exemple:
    * - pour les données brutes exportés par SuSo, c'est "menage.dta" et "membres.dta", respectivement
    * - pour les données apurées et harmonisées, il s'agit des bases s00 et s01, respectivement

* sortie:
local hhold_file_out    "menage.tab"
    * nom du fichier = questionnaire variable
    * afin de retrouver ce nom: 
    * - ouvrir le questionnaire dans Designer
    * - cliquer sur PARAMÈTRES
    * - copier la valeur du champs `Questionnaire variable`
local member_file_out   "membres.tab"
    * ROSTER des membres
    * nom du fichier = (premier) roster ID dans Designer

/*=============================================================================
CRÉER DES AFFECTATIONS
=============================================================================*/

/*-----------------------------------------------------------------------------
Créer un nouvel ID de l'entretien 
-----------------------------------------------------------------------------*/

* SuSo demande un ID unique qui s'appelle `interview__id`. Créer un numéro séquentiel pour chaque observation
use "`input_dir`/`hhold_file_in'", clear
gen interview__id_new = _n
tempfile menages
save "`menages'", replace

* NB: pour fusionner les bases menage et membres, on a besoin de variables qui :
* - sont disponbiles dans les deux bases et 
* - qui identifient uniquement chaque ménage
* Ces variables peuvent être différente selon la nature des bases d'entrée
* - pour les données brutes exportés par SuSo, c'est interview__id
* - pour les données apurées (e.g., les bases s00 et s01), c'est hhid ou la combinaison de grappe et menage

* ajouter ce nouvel ID à chaque fichier
use "`input_dir`/`member_file_in'", clear
merge m:1 interview__id using "`menages'",  /// fusionner par hhid
    keepusing(interview__id_new)            /// ajouter la variable interview__id du fichier ménage
    keep(3) nogen noreport                  /// ne créer pas _merge; n'afficher pas les résultats; retenir les cas en commun
tempfile membres
save "`membres'", replace

/*-----------------------------------------------------------------------------
Créer un roster des membres 
-----------------------------------------------------------------------------*/

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Retenir les individus toujours membre du ménage
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
 
use "`membres'", clear
* Garder les personnes toujours membre du ménage (selon la dernière enquête)
* NB: ceci n'est pertinent que pour les enquêtes téléphoniques où l'on
* constate le départ des membres
* NB: le nom de la variable doit être adapté à vos données
keep if toujours_membre == 1

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Créer des variables à précharger
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

* renommer/créer des variables pour s'accorder avec SuSo
// ID panel du membre
gen preload_pid = s01q00a
// sexe
gen preload_sex = s01q01
// âge lors de l'EHCVM
gen preload_age = AgeAnnee // ou à défaut de cela, s01q04a
// lien de parenté
gen preload_relation = s01q02

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Renuméroter l'identifiant des membres
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

* trier par identifiant de ménage et de membre
* pas strictement nécessaire; juste plus propre
sort interview__id s01q00a
* NB: si la base contient la variable membres__id déjà, il faut la supprimer
* créer un nouveau numéro séquentiel pour identifier les membres
* pourquoi?
* SuSo a besoin d'un ID membre qui:
* - commence à partir de 0
* - est séquentiel
* - n'a pas de lacunes dans la séquence
* Ceci garanti que la liste des membres (diapo suivant) est de la bonne forme
* L'ID membre peut ne pas être séquentiel pour plusieurs raisons :
* - Membres éliminés (voir plus tôt ce diapo)
* - Lacunes existent à cause du processus de capter les infos (e.g., membre ajouté puis supprimé par l'enquêteur)
bysort interview__id: generate membres__id = _n

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Retenir les informations pertinentes
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

keep interview__id_new interview__id members__id /// IDs
    preload_pid         /// identifiant panel du membre
    preload_sex         /// sexe
    preload_age         /// âge
    preload_relation    /// lien de parenté
    NOM_PRENOMS         /// nom
    s01q01              /// sexe
    s01q02              /// lien de parenté
    s01q03a             /// DDN: jour
    s01q03b             /// DDN: mois
    s01q03c             /// DDN: année

/*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Sauvegarder le roster
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

* préparer pour la création d'une liste
* rien à modifier
tempfile membres_pour_liste
save "`membres_pour_liste'"

* préparer pour le préchargement du roster
* retenir le nouvel identifiant ménage
drop interview__id
rename interview__id_new interview__id
tempfile membres_roster
save "`membres_roster'"

/*-----------------------------------------------------------------------------
Créer une liste des membres 
-----------------------------------------------------------------------------*/

use "`membres_pour_liste'", clear
keep interview__id_new membres__id NOM_PRENOMS
* La liste de SuSo est indexée à 0
* membres__id commence avec 1
* soustraire 1 de membres__id pour que les deux s'accordent
replace membres__id = membres__id - 1
* Les questions liste de SuSo's sont formattées comme suit :
* - chaque élément de la liste occupe sa propre colonne
* - le nom de chaque élément consiste de: du nom de variable chez Designer, 
*    le texte __ comme séparateur, et de l'indice de l'élément (e.g. var__0 pour le 1ier élément, var__2 pour le 2e, etc)
* Afin de ramener la base dans le format demandé par SuSo:
* renommer la variable pour être du format var__
rename NOM_PRENOMS NOM_PRENOMS__
* remodeler les données de sorte que chaque élément soit une colonne et chaque 
* colonne ait un nom de la forme var__0, var__1, etc.
reshape wide NOM_PRENOMS__, i(interview__id_new) j(membres__id)
tempfile membres_liste
save "`membres_liste'"

/*-----------------------------------------------------------------------------
Créer une base niveau ménage 
-----------------------------------------------------------------------------*/

use "`menages'", clear

* créer des variables pour les besoin d'identification
gen vague = 3               // vague de collecte
gen s00q07f1 = grappe       // ancien numéro de grappe
gen s00q07f2 = id_menage    // ancien numéro de ménage
gen s00q07a = 1             // tout ancien ménage est résident

* retenir seulement les variables anticipées par SuSo
* comme SuSo ne sait pas comment
* gérer des variables supplémentaires
keep interview__id interview__id_new ///
    grappe id_menage vague nom_prenom_cm localisation_menage /// couverture
    s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07 s00q07a s00q07f* /// identification
    s00q28 /// langue de l'entretien: à retenir seulement si l'affectation se fait sur cette base

tempfile menages
save "`menages'", replace

/*-----------------------------------------------------------------------------
Ajouter la liste à la base ménage 
-----------------------------------------------------------------------------*/

use "`menages'", clear
* ajouter la question liste à la base ménage
merge 1:1 interview__id_new using "`membres_liste'", nogen noreport assert(3) keep(3)
capture drop interview__id
rename interview__id_new interview__id

tempfile menages_plus_liste
save "`menages_plus_liste'"

/*-----------------------------------------------------------------------------
Créer une liste des variables à protéger 
-----------------------------------------------------------------------------*/

* créer une base de la forme suivante :
* | variable__name  |
* | --------------- |
* | "var1"          |
* | "var2"          |
* créer une base vide avec 1 observation
clear
set obs 1

* peupler l'observation avec le nom de la
* variable dont les valeurs préchargées sont à protéger
* typiquement, il s'agit de questions qui enclenchent un roster
* comme la liste ici-bas
gen variable__name = ""
replace variable__name = "NOM_PRENOMS" in 1

tempfile protected_vars
save "`protected_vars'"

/*-----------------------------------------------------------------------------
Décider de l'affection
-----------------------------------------------------------------------------*/

* Voir les options

/*=============================================================================
Valider le travail
=============================================================================*/

/*-----------------------------------------------------------------------------
Noms attendus
-----------------------------------------------------------------------------*/

use "`menages_plus_liste'", clear

* liste (indicative) des variables à vérifier
* action: la liste doit correspondre aux variables attendues dans la base
local expected_vars "interview__id grappe menage_id vague nom_prenom_cm localisation_menage NOM_PRENOMS__0 s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07"
foreach expected_var of local expected_vars {
    * vérifier si chaque variable attendue existe dans la base
    * si oui, passer à la suivante
    * sinon, échouer bruyamment
    capture confirm variable `expected_var'
    if (_rc != 0) {
        di "Variable `expected_var' n'a pas été retrouvée."
        error 1
    }
}

/*-----------------------------------------------------------------------------
Types attendus
-----------------------------------------------------------------------------*/

local expected_vars "interview__id grappe menage_id vague nom_prenom_cm localisation_menage NOM_PRENOMS__0 s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07"
local expected_types "numeric numeric numeric numeric str str str numeric numeric numeric numeric numeric str numeric numeric"
local num_vars: word count `expected_vars'
forvalues i = 1/`num_vars' {
    local expected_var: word `i' of `expected_vars'
    local expected_type: word `i' of `expected_types'
    * vérifier si chaque variable attendue a le bon type
    * si oui, passer à la suivante
    * sinon, échouer bruyamment
    capture confirm `expected_type' variable `expected_var'
    if (_rc != 0) {
        di "Variable `expected_var' attendue comme `expected_type', mais un autre type a été détecté"
        error 1
    }
}

/*-----------------------------------------------------------------------------
Tout affecté
-----------------------------------------------------------------------------*/

* tous les entretiens ont un responsable désigné
capture assert _responsible != ""
if _rc != 0 {
    qui: count if _responsible == ""
    local num_miss = r(N)
    di "Toute affectation doit être assignée. Mais `num_miss' ne l'ont pas été."
    error 1
}

/*-----------------------------------------------------------------------------
Liste complète
-----------------------------------------------------------------------------*/

* la liste des membres n'est pas vide
capture assert !inlist(NOM_PRENOMS__0, "", " ")
if _rc != 0 {
    qui: count if inlist(NOM_PRENOMS__0, "", " ")
    local num_miss = r(N)
    di "Les listes ne devraient pas avoir des éléments vides. Mais `num_miss' instances de NOM_PRENOMS__0 ont une valeur nulle/vide."
}

/*=============================================================================
Sauvegarder
=============================================================================*/

/*-----------------------------------------------------------------------------
Sauvegarder vers le format tab
-----------------------------------------------------------------------------*/

* NIVEAU MÉNAGE
* nom du fichier = questionnaire variable
* afin de retrouver ce nom: 
* - ouvrir le questionnaire dans Designer
* - cliquer sur PARAMÈTRES
* - copier la valeur depuis Questionnaire variable
use "`menages_plus_liste'", clear
outsheet using "`output_dir'/`hhold_file_out'", ///
    nolabel /// sauvegarder les valeurs, pas les étiquettes
    noquote /// pas de guillemets pour les variables texte
    replace

* NIVEAU MEMBRES
* nom du fichier = (premier) roster ID pour ce roster dans Designer
use "`membres_roster'", clear
outsheet using "`output_dir'/`member_file_out'", ///
    nolabel /// sauvegarder les valeurs, pas les étiquettes
    noquote /// pas de guillemets pour les variables texte
    replace

* VARIABLE DONT LES VALEURS PRÉCHARGÉES SONT À PROTÉGER
* nom du fichier = nom imuable attendu par le système: protected__variables
use "`protected_vars'", clear
outsheet using "`output_dir'/protected__variables.tab", noquote replace

/*-----------------------------------------------------------------------------
Créer un fichier zip à importer dans Headquarters
-----------------------------------------------------------------------------*/

* rediriger vers le dossier où mettre le fichier zip
cd "`output_dir'"

* lister tous les fichiers se terminant en ".tab"
* créer un fichier zip pour les regrouper
* sauvegarder "affectations.zip"
zipfile "*.tab", saving("affectations_anciens_menages.zip", replace)
