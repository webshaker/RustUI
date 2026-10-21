//! Separateurs d'un pixel, repris de SimulateurThermique.

use iced::widget::container::Style;
use iced::widget::{Space, container};
use iced::{Color, Element, Length};

pub fn horizontal_separator<'a, Message: 'a>() -> Element<'a, Message> {
    container(Space::new(0, 0))
        .width(Length::Fill)
        .height(1)
        .style(|_| Style {
            background: Some(Color::BLACK.into()),
            ..Default::default()
        })
        .into()
}

pub fn vertical_separator<'a, Message: 'a>() -> Element<'a, Message> {
    container(Space::new(0, 0))
        .width(1)
        .height(Length::Fill)
        .style(|_| Style {
            background: Some(Color::BLACK.into()),
            ..Default::default()
        })
        .into()
}
