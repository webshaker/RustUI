//! Ce qu'une action peut demander a l'interface, en plus de modifier les
//! donnees : choisir un fichier, changer d'ecran, copier du texte, quitter.
//!
//! Une action reste un simple `|doc| ...` : elle appelle ces fonctions, et
//! RustUI les execute juste apres elle.
//!
//! ```ignore
//! fn ouvrir(&mut self) {
//!     rust_ui::open_file("Ouvrir un banc", &[("Banc", &["banc"])], |doc: &mut Document, chemin| doc.charger(chemin));
//! }
//! ```

use std::any::Any;
use std::cell::RefCell;
use std::path::PathBuf;

/// Un effet en attente.
pub(crate) enum Effet {
    Fichier {
        titre: String,
        filtres: Vec<(String, Vec<String>)>,
        /// `Some(nom propose)` : enregistrer ; `None` : ouvrir.
        enregistrer: Option<String>,
        dossier: Option<PathBuf>,
        /// `Box<dyn Fn(&mut D, PathBuf)>`, le type des donnees n'etant connu que du moteur.
        suite: Box<dyn Any>,
    },
    Ecran(String),
    Copier(String),
    Quitter,
}

thread_local! {
    static EN_ATTENTE: RefCell<Vec<Effet>> = const { RefCell::new(Vec::new()) };
}

fn demander(e: Effet) {
    EN_ATTENTE.with(|f| f.borrow_mut().push(e));
}

/// Les effets demandes depuis le dernier appel (le moteur les execute).
pub(crate) fn prendre() -> Vec<Effet> {
    EN_ATTENTE.with(|f| std::mem::take(&mut *f.borrow_mut()))
}

type Suite<D> = Box<dyn Fn(&mut D, PathBuf)>;

fn filtres(f: &[(&str, &[&str])]) -> Vec<(String, Vec<String>)> {
    f.iter().map(|(n, e)| (n.to_string(), e.iter().map(|x| x.to_string()).collect())).collect()
}

/// Fait choisir un fichier a ouvrir ; `then` le recoit (rien si l'on annule).
/// `filters` : `[("Banc", &["banc"])]`.
pub fn open_file<D: 'static>(title: &str, filters: &[(&str, &[&str])], then: impl Fn(&mut D, PathBuf) + 'static) {
    let suite: Suite<D> = Box::new(then);
    demander(Effet::Fichier { titre: title.into(), filtres: filtres(filters), enregistrer: None, dossier: None, suite: Box::new(suite) });
}

/// Fait choisir ou enregistrer, avec un nom propose et un dossier de depart.
pub fn save_file<D: 'static>(
    title: &str,
    filters: &[(&str, &[&str])],
    proposed_name: &str,
    folder: Option<PathBuf>,
    then: impl Fn(&mut D, PathBuf) + 'static,
) {
    let suite: Suite<D> = Box::new(then);
    demander(Effet::Fichier { titre: title.into(), filtres: filtres(filters), enregistrer: Some(proposed_name.into()), dossier: folder, suite: Box::new(suite) });
}

/// Affiche l'ecran `name`.
pub fn show_screen(name: &str) {
    demander(Effet::Ecran(name.into()));
}

/// Copie `text` dans le presse-papiers.
pub fn copy_to_clipboard(text: impl Into<String>) {
    demander(Effet::Copier(text.into()));
}

/// Ferme l'application.
pub fn quit() {
    demander(Effet::Quitter);
}
