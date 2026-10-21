//! Le lancement d'une application : sa fenetre, son theme, sa boucle.
//!
//! L'application decrit ce qu'elle est (titre, mise a jour, vue, abonnements) ;
//! RustUI s'occupe du reste. Elle n'a pas a connaitre le moteur graphique.
//!
//! ```ignore
//! impl rust_ui::Application for App {
//!     type Message = Message;
//!     fn title(&self) -> String { "Mon outil".into() }
//!     fn update(&mut self, m: Message) -> rust_ui::Task<Message> { ... }
//!     fn view(&self) -> rust_ui::Element<'_, Message> { ... }
//! }
//!
//! fn main() -> rust_ui::AppResult {
//!     rust_ui::new_app(rust_ui::Window::new(1600.0, 1000.0), App::new)
//! }
//! ```

use iced::{Element, Subscription, Task, Theme, window};

/// Ce que fait une application ; RustUI la fait tourner.
pub trait Application: Sized + 'static {
    /// Les evenements de l'application.
    type Message: std::fmt::Debug + Send + 'static;

    /// Titre de la fenetre.
    fn title(&self) -> String;

    /// Traite un evenement ; la tache rendue peut en produire d'autres.
    fn update(&mut self, message: Self::Message) -> Task<Self::Message>;

    /// Ce qu'on affiche.
    fn view(&self) -> Element<'_, Self::Message>;

    /// Evenements exterieurs (clavier, minuterie...). Aucun par defaut.
    fn subscription(&self) -> Subscription<Self::Message> {
        Subscription::none()
    }
}

/// La fenetre principale.
#[derive(Debug, Clone, Copy)]
pub class Window {
    pub width: f32,
    pub height: f32,
    /// La croix ne ferme pas : l'application recoit la demande et decide
    /// (par exemple pour proteger un document non enregistre), puis quitte
    /// avec `rust_ui::exit()`.
    pub manual_close: bool,

    pub fn new(width: f32, height: f32) -> Self {
        Self { width, height, manual_close: false }
    }

    /// Voir `manual_close`.
    pub fn manual_close(mut self) -> Self {
        self.manual_close = true;
        self
    }
}

/// Resultat de `new_app`.
pub type AppResult = iced::Result;

/// Ouvre la fenetre et fait tourner l'application jusqu'a sa fermeture.
/// Theme sombre et anticrenelage, communs a toutes les applications RustUI.
pub fn new_app<A: Application>(win: Window, boot: impl FnOnce() -> (A, Task<A::Message>) + 'static) -> AppResult {
    iced::application(A::title, A::update, A::view)
        .subscription(A::subscription)
        .theme(|_| Theme::Dark)
        .antialiasing(true)
        .window(window::Settings {
            size: iced::Size::new(win.width, win.height),
            exit_on_close_request: !win.manual_close,
            ..Default::default()
        })
        .run_with(boot)
}

/// Ferme l'application (apres un `manual_close`).
pub fn exit<Message>() -> Task<Message> {
    iced::exit()
}
