defmodule AshIntro.Scraping.HTML do
  @moduledoc """
  HTML scraping with utilities. Start with `parse_document/1`.
  """

  @doc """
  Initial parse step. Result is `{:ok, internal}` or `{:error, reason}`.
  """
  def parse_document(binary) do
    fixed_html = ensure_closed_head(binary)

    with {:ok, floki} <- Floki.parse_document(fixed_html), do: {:ok, {__MODULE__, floki}}
  end

  defp ensure_closed_head(html) when is_binary(html) do
    if String.contains?(html, "</head>") do
      html
    else
      Regex.replace(~r/<body\b/, html, "</head><body")
    end
  end

  @doc """
  Extracts and returns text, with links inlined in markdown syntax.
  """
  # TODO this is way too specific, but generalizing it would mean writing a very clever recursion...
  def text_with_links_in_markdown({__MODULE__, floki}) do
    do_text_with_links_in_markdown(floki)
  end

  defp do_text_with_links_in_markdown(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&do_text_with_links_in_markdown/1)
    |> Enum.join(" ")
  end

  @exlude_tags ~w{head rect svg path meta script style nav footer img}

  defp do_text_with_links_in_markdown({tag, _attrs, _children}) when tag in @exlude_tags, do: ""
  defp do_text_with_links_in_markdown({:comment, _}), do: ""

  defp do_text_with_links_in_markdown({"a", attrs, children}) do
    href =
      attrs
      |> Enum.find_value("", fn
        {"href", val} -> val
        _ -> nil
      end)

    link_text = do_text_with_links_in_markdown(children)
    "[#{link_text}](#{href})"
  end

  defp do_text_with_links_in_markdown({_tag, _attrs, children}),
    do: do_text_with_links_in_markdown(children)

  defp do_text_with_links_in_markdown(text) when is_binary(text),
    do: String.replace(text, ~r/\s+/, " ")

  @doc """
  Pass result of parse_document/1.

  Returns list of URI structs from "a[href]" in the content
  """
  def link_uris({__MODULE__, floki}) do
    # Note: URI.new won't tolerate "tel:" hrefs

    floki
    |> Floki.find("a[href]")
    |> Floki.attribute("href")
    |> Enum.map(&URI.parse/1)
  end

  @doc """
  Returns whether `uri` is below `other_uri`.
  """
  def uri_below?(%URI{} = uri, %URI{} = other_uri) do
    cond do
      strip_uri(uri, keep: :authority) != strip_uri(other_uri, keep: :authority) ->
        false

      Path.relative_to(uri.path || "/", other_uri.path || "/") |> String.starts_with?("/") ->
        false

      true ->
        true
    end
  end

  @doc """
  Strip the URI struct. Keep everything that is less specific than the `keep` option.

  * `keep: :path`: strips query and fragment
  * `keep: :authority`: also strips path
  """
  def strip_uri(uri, opts)
  def strip_uri(uri, keep: :path), do: %{uri | query: nil, fragment: nil}
  def strip_uri(uri, keep: :authority), do: %{uri | query: nil, fragment: nil, path: nil}
end
