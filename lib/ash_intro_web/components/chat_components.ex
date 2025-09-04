defmodule AshIntroWeb.ChatComponents do
  use Phoenix.Component

  attr :text, :string, required: true

  def markdown(assigns) do
    markdown_html =
      assigns.text
      |> markdown_to_raw_html()

    assigns = assign(assigns, :markdown, markdown_html)

    ~H"""
    {Phoenix.HTML.raw(@markdown)}
    """
  end

  defp markdown_to_raw_html(nil), do: ""

  defp markdown_to_raw_html(text) do
    Logger.disable(self())

    text
    |> String.trim()
    |> Earmark.as_html!(code_class_prefix: "lang- language-")
  after
    Logger.enable(self())
  end
end
