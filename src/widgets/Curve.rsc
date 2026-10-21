//! Curve d'un signal echantillonne (option `canvas`), facon oscilloscope :
//! chaque valeur est tenue jusqu'au point suivant, une valeur inconnue laisse
//! un trou, et le survol donne l'abscisse et la valeur sous la souris.
//!
//! ```ignore
//! Curve::new(points, "V", 0.0, 10e6)
//!     .x_label(|t| format!("{:.3} ms", t / 1e6))
//!     .view(100.0)
//! ```

#[cfg(feature = "canvas")]
use iced::widget::canvas;
#[cfg(feature = "canvas")]
use iced::{Color, Element, Length, Point, Rectangle, Renderer, Theme, mouse};

#[cfg(feature = "canvas")]
#[derive(Debug, Clone)]
pub class Curve {
    /// (abscisse, valeur) par abscisse croissante ; `None` : inconnu.
    pub points: Vec<(f64, Option<f64>)>,
    pub unit: String,
    /// Fenetre affichee, en abscisses.
    pub start: f64,
    pub end: f64,
    /// Texte d'une abscisse, au survol.
    pub x_label: fn(f64) -> String,

    pub fn new(points: Vec<(f64, Option<f64>)>, unit: impl Into<String>, start: f64, end: f64) -> Self {
        Self { points, unit: unit.into(), start, end, x_label: |x| format!("{x:.3}") }
    }

    /// Mise en forme de l'abscisse au survol.
    pub fn x_label(mut self, f: fn(f64) -> String) -> Self {
        self.x_label = f;
        self
    }

    /// La courbe sur toute la largeur, a la hauteur donnee.
    pub fn view<'a, Message: 'a>(self, height: f32) -> Element<'a, Message> {
        canvas(self).width(Length::Fill).height(height).into()
    }

    impl<Message> canvas::Program<Message> {
        type State = ();

        fn draw(&self, _: &(), renderer: &Renderer, _: &Theme, bounds: Rectangle, cursor: mouse::Cursor) -> Vec<canvas::Geometry> {
            let mut f = canvas::Frame::new(renderer, bounds.size());
            let h = bounds.height;
            f.fill_rectangle(Point::ORIGIN, bounds.size(), Color::from_rgb(0.08, 0.10, 0.12));
            let valeurs: Vec<f64> = self.points.iter().filter_map(|(_, v)| *v).collect();
            let min = valeurs.iter().copied().fold(0.0, f64::min);
            let max = valeurs.iter().copied().fold(1.0, f64::max);
            let x = |t: f64| (((t - self.start) / (self.end - self.start).max(1.0)) * bounds.width as f64) as f32;
            // Le trace occupe de 20 % a 80 % de la hauteur ; le texte, le bas.
            let y = |v: f64| h * 0.8 - ((v - min) / (max - min).max(1e-12)) as f32 * h * 0.6;
            for i in 0..self.points.len() {
                let (t, v) = self.points[i];
                let fin = self.points.get(i + 1).map(|p| p.0).unwrap_or(self.end);
                if fin < self.start || t > self.end {
                    continue;
                }
                if let Some(v) = v {
                    let p = canvas::Path::new(|p| {
                        p.move_to(Point::new(x(t).max(0.0), y(v)));
                        p.line_to(Point::new(x(fin).min(bounds.width), y(v)));
                        if let Some(Some(suivante)) = self.points.get(i + 1).map(|p| p.1)
                            && x(fin) <= bounds.width
                        {
                            p.line_to(Point::new(x(fin), y(suivante)));
                        }
                    });
                    f.stroke(&p, canvas::Stroke::default().with_color(Color::from_rgb(0.45, 0.82, 1.0)).with_width(1.5));
                }
            }
            let texte = if let Some(p) = cursor.position_in(bounds) {
                let t = self.start + p.x as f64 / bounds.width as f64 * (self.end - self.start);
                let valeur = self
                    .points
                    .iter()
                    .rev()
                    .find(|p| p.0 <= t)
                    .and_then(|p| p.1)
                    .map(|v| format!("{v:.5} {}", self.unit))
                    .unwrap_or("inconnu".into());
                f.stroke(&canvas::Path::line(Point::new(p.x, 0.0), Point::new(p.x, h)), canvas::Stroke::default().with_color(Color::WHITE));
                format!("{} : {valeur}", (self.x_label)(t))
            } else {
                format!("{min:.4} … {max:.4} {}", self.unit)
            };
            f.fill_text(canvas::Text { content: texte, position: Point::new(6.0, h * 0.82), color: Color::WHITE, size: 12.0.into(), ..Default::default() });
            vec![f.into_geometry()]
        }
    }
}
