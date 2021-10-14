/*=============================================================================
PARAMÈTRES DU PROJET
=============================================================================*/

* DOSSIERS
local proj_dir      ""    // où trouver la "racine" du projet
local input_dir     ""    // où trouver les fichiers d'entree. Par exemple: "`proj_dir'/entree/"
local output_dir    ""    // où trouver les fichiers de sortie. Par example: "`proj_dir'/sortie/"

* FICHIERS
* entrée:
local sel_hholds_file_in     "nom_a_determiner.dta"    // fichier des ménages tirés

* sortie:
local hhold_file_out    "menage.tab"
    * nom du fichier = questionnaire variable
    * afin de retrouver ce nom: 
    * - ouvrir le questionnaire dans Designer
    * - cliquer sur PARAMÈTRES
    * - copier la valeur du champs `Questionnaire variable`

/*=============================================================================
CRÉER DES AFFECTATIONS
=============================================================================*/

/*-----------------------------------------------------------------------------
Retenir les informations nécessaires
-----------------------------------------------------------------------------*/

use "`input_dir'/`sel_hholds_file_in'", clear

* NB: il est possible qu'il y ait des manipulations à faire pour avoir une base
* de la forme et du contenu souhaité
gen vague = 3

* retenir les variables à précharger
keep interview__id ///
    grappe id_menage vague nom_prenom_cm localisation_menage    /// couverture
    s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07     /// identification

/*-----------------------------------------------------------------------------
Créer un nouvel ID de l'entretien
-----------------------------------------------------------------------------*/

* SuSo demande un ID unique qui s'appelle `interview__id`
* Une approche simple consiste à créer un
* numéro séquentiel pour chaque observation
drop interview__id      // écraser l'identifiant de la base source
gen interview__id = _n  // créer un nouvel identifiant
tempfile households
save "`menages'", replace

/*-----------------------------------------------------------------------------
Affecter aux équipes de terrain
-----------------------------------------------------------------------------*/

* Voir les options

/*=============================================================================
Valider le travail
=============================================================================*/

/*-----------------------------------------------------------------------------
Noms attendus
-----------------------------------------------------------------------------*/

* liste (indicative) des variables à vérifier
* action: la liste doit correspondre aux variables attendues dans la base
local expected_vars "interview__id grappe menage_id vague nom_prenom_cm localisation_menage s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07"
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

local expected_vars "interview__id grappe menage_id vague nom_prenom_cm localisation_menage s00q00 s00q01 s00q02 s00q03 s00q04 s00q05 s00q06 s00q07"
local expected_types "numeric numeric numeric numeric str str numeric numeric numeric numeric numeric str numeric numeric"
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

/*=============================================================================
Sauvegarder
=============================================================================*/

/*-----------------------------------------------------------------------------
Sauvegarder vers le format tab 
-----------------------------------------------------------------------------*/

use "`menages'", clear
outsheet using "`output_dir'/`hhold_file_out'", ///
    nolabel /// sauvegarder les valeurs, pas les étiquettes
    noquote /// pas de guillemets pour les variables texte
    replace

/*-----------------------------------------------------------------------------
Zipper le fichier tab 
-----------------------------------------------------------------------------*/
 
* rediriger vers le dossier où mettre le fichier zip
cd "`output_dir'"

* sauvegarder "affectations_nouveaux_menages.zip"
zipfile "`hhold_file_out'", saving("affectations_nouveaux_menages.zip", replace)
