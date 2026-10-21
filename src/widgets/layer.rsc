//! `Calque` : un widget qui dessine son contenu dans un calque rogne a ses
//! bornes.
//!
//! Dans iced 0.13, `container(...).clip(true)` ne fait que restreindre le
//! viewport logique et `Frame::with_clip` ne rogne que les maillages, pas les
//! images. Seul un calque (`Renderer::with_layer`) pose un ciseau GPU qui
//! s'applique aussi au pipeline image — c'est ce que fait `scrollable`. Sans
//! lui, une image zoomee dans le canvas deborde sur le panneau et le menu.

use iced::advanced::layout::{self, Layout};
use iced::advanced::renderer;
use iced::advanced::widget::{Operation, Tree, Widget};
use iced::advanced::{Clipboard, Renderer as _, Shell, overlay};
use iced::{Element, Event, Length, Rectangle, Renderer, Size, Theme, Vector, event, mouse};

pub struct Calque<'a, Message> {
    contenu: Element<'a, Message>,
}

/// Enveloppe `contenu` dans un calque rogne a ses bornes.
pub fn layer<'a, Message: 'a>(contenu: impl Into<Element<'a, Message>>) -> Element<'a, Message> {
    Element::new(Calque {
        contenu: contenu.into(),
    })
}

impl<Message> Widget<Message, Theme, Renderer> for Calque<'_, Message> {
    fn size(&self) -> Size<Length> {
        self.contenu.as_widget().size()
    }

    fn size_hint(&self) -> Size<Length> {
        self.contenu.as_widget().size_hint()
    }

    fn layout(&self, tree: &mut Tree, renderer: &Renderer, limits: &layout::Limits) -> layout::Node {
        self.contenu.as_widget().layout(&mut tree.children[0], renderer, limits)
    }

    fn draw(
        &self,
        tree: &Tree,
        renderer: &mut Renderer,
        theme: &Theme,
        style: &renderer::Style,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        viewport: &Rectangle,
    ) {
        let bounds = layout.bounds();
        let Some(visible) = bounds.intersection(viewport) else {
            return;
        };
        renderer.with_layer(visible, |renderer| {
            self.contenu
                .as_widget()
                .draw(&tree.children[0], renderer, theme, style, layout, cursor, &visible);
        });
    }

    fn children(&self) -> Vec<Tree> {
        vec![Tree::new(&self.contenu)]
    }

    fn diff(&self, tree: &mut Tree) {
        tree.diff_children(std::slice::from_ref(&self.contenu));
    }

    fn operate(&self, tree: &mut Tree, layout: Layout<'_>, renderer: &Renderer, operation: &mut dyn Operation) {
        self.contenu
            .as_widget()
            .operate(&mut tree.children[0], layout, renderer, operation);
    }

    fn on_event(
        &mut self,
        tree: &mut Tree,
        event: Event,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        renderer: &Renderer,
        clipboard: &mut dyn Clipboard,
        shell: &mut Shell<'_, Message>,
        viewport: &Rectangle,
    ) -> event::Status {
        self.contenu.as_widget_mut().on_event(
            &mut tree.children[0],
            event,
            layout,
            cursor,
            renderer,
            clipboard,
            shell,
            viewport,
        )
    }

    fn mouse_interaction(
        &self,
        tree: &Tree,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        viewport: &Rectangle,
        renderer: &Renderer,
    ) -> mouse::Interaction {
        self.contenu
            .as_widget()
            .mouse_interaction(&tree.children[0], layout, cursor, viewport, renderer)
    }

    fn overlay<'b>(
        &'b mut self,
        tree: &'b mut Tree,
        layout: Layout<'_>,
        renderer: &Renderer,
        translation: Vector,
    ) -> Option<overlay::Element<'b, Message, Theme, Renderer>> {
        self.contenu
            .as_widget_mut()
            .overlay(&mut tree.children[0], layout, renderer, translation)
    }
}
