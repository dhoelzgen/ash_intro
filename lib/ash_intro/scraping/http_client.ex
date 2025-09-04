defmodule AshIntro.Scraping.HTTPClient do
  @max_depth 5
  @timeout 30_000

  def get(url, name, depth \\ @max_depth), do: do_get(url, name, depth)

  def do_get(_url, _name, 0), do: {:error, :maximum_depth_exceeded}

  def do_get(url, name, depth) do
    headers = [
      {"User-Agent", "AshIntro/1.0"},
      {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"}
    ]

    Finch.build(:get, url, headers)
    |> Finch.request(name, receive_timeout: @timeout)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers}}
      when status in [301, 302, 303, 307, 308] ->
        location = find_header(headers, "location")

        if location do
          absolute_location = resolve_url(location, relative_to: url)

          do_get(absolute_location, name, depth - 1)
        else
          {:error, :missing_location_header}
        end

      {:ok, %Finch.Response{status: status}} when status >= 400 ->
        {:error, {:http_error, status}}

      other ->
        other
    end
  end

  defp find_header(headers, key) do
    Enum.find_value(headers, fn
      {k, v} when is_binary(k) -> if String.downcase(k) == String.downcase(key), do: v, else: nil
      {k, v} -> if to_string(k) == key, do: v, else: nil
    end)
  end

  defp resolve_url(location, relative_to: base_url) do
    URI.merge(base_url, location) |> URI.to_string()
  end
end
