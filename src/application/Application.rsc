//! Le lancement d'une application : sa fenetre, son theme, sa boucle.
//!
//! L'application decrit ce qu'elle est (titre, mise a jour, vue, abonnements) ;
//! RustUI s'occupe du reste. Elle n'a pas a connaitre le moteur graphique.
//!
//! ```ignore
//! impl rust_ui::Application for App {
//!     type Message = Message;
//!     fn titre(&self) -> String { "Mon outil".into() }
//!     fn mise_a_jour(&mut self, m: Message) -> rust_ui::Task<Message> { ... }
//!     fn vue(&self) -> rust_ui::Element<'_, Message> { ... }
//! }
//!
//! fn main() -> rust_ui::Resultat {
//!     rust_ui::lancer(rust_ui::Fenetre::new(1600.0, 1000.0), App::new)
//! }
//! ```

use iced::{Element, Subscription, Task, Theme, window};

/// Ce que fait une application ; RustUI la fait tourner.
pub trait Application: Sized + 'static {
    /// Les evenements de l'application.
    type Message: std::fmt::Debug + Send + 'static;

    /// Titre de la fenetre.
    fn titre(&self) -> String;

    /// Traite un evenement ; la tache rendue peut en produire d'autres.
    fn mise_a_jour(&mut self, message: Self::Message) -> Task<Self::Message>;

    /// Ce qu'on affiche.
    fn vue(&self) -> Element<'_, Self::Message>;

    /// Evenements exterieurs (clavier, minuterie...). Aucun par defaut.
    fn abonnements(&self) -> Subscription<Self::Message> {
        Subscription::none()
    }
}

/// La fenetre principale.
#[derive(Debug, Clone, Copy)]
pub class Fenetre {
    pub largeur: f32,
    pub hauteur: f32,
    /// La croix ne ferme pas : l'application recoit la demande et decide
    /// (par exemple pour proteger un document non enregistre). Elle quitte
    /// alors avec `rust_ui::quitter()`.
    pub fermeture_manuelle: bool,

    pub fn new(largeur: f32, hauteur: f32) -> Self {
        Self { largeur, hauteur, fermeture_manuelle: false }
    }

    /// Voir `fermeture_manuelle`.
    pub fn fermeture_manuelle(mut self) -> Self {
        self.fermeture_manuelle = true;
        self
    }
}

/// Resultat de `lancer`.
pub type Resultat = iced::Result;

/// Ouvre la fenetre et fait tourner l'application jusqu'a sa fermeture.
/// Theme sombre et anticrenelage, communs a toutes les applications RustUI.
pub fn lancer<A: Application>(fenetre: Fenetre, demarrer: impl FnOnce() -> (A, Task<A::Message>) + 'static) -> Resultat {
    iced::application(A::titre, A::mise_a_jour, A::vue)
        .subscription(A::abonnements)
        .theme(|_| Theme::Dark)
        .antialiasing(true)
        .window(window::Settings {
            size: iced::Size::new(fenetre.largeur, fenetre.hauteur),
            exit_on_close_request: !fenetre.fermeture_manuelle,
            ..Default::default()
        })
        .run_with(demarrer)
}

/// Ferme l'application (apres une `fermeture_manuelle`).
pub fn quitter<Message>() -> Task<Message> {
    iced::exit()
}
