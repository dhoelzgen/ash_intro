defmodule AshIntro.Scraping.Changes.Crawl do
  use Ash.Resource.Change
  require Logger

  @impl true
  def change(changeset, opts, context) do
    ash_opts = Ash.Context.to_opts(context)

    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      case result do
        {:ok, container} ->
          # For demo purposes, we clear on start, too. Doesn't make sense for a real app.
          with :ok <- ensure_required_opts(opts),
               {:ok, _container} <- set_processing!(container, ash_opts),
               {:ok, _cleared} <- clear_entities(container, opts, ash_opts),
               {:ok, html_content} <- crawl(container),
               {:ok, drafts} <- extract(container, html_content, opts, ash_opts),
               {:ok, _persisted} <- sync_drafts(container, drafts, opts, ash_opts) do
            set_ready!(container, ash_opts)
          else
            error ->
              Logger.error(fn ->
                {"Crawler: Error during crawl process - #{inspect(error)}", error: inspect(error)}
              end)

              set_error!(container, ash_opts)
          end

        {:error, error} ->
          Logger.error(fn ->
            {"Crawler: Could not initialize crawler", error: inspect(error)}
          end)
      end

      result
    end)
  end

  defp crawl(container) do
    with(
      {:ok, response} <- AshIntro.Scraping.HTTPClient.get(container.url, AshIntro.Scraping.Finch),
      {:ok, parsed} <- AshIntro.Scraping.HTML.parse_document(response.body)
    ) do
      {:ok, AshIntro.Scraping.HTML.text_with_links_in_markdown(parsed)}
    end
  end

  defp extract(container, html_content, _opts, ash_opts) do
    container.__struct__
    |> Ash.ActionInput.for_action(:extract, %{text: html_content}, ash_opts)
    |> Ash.run_action()
  end

  defp set_processing!(container, ash_opts) do
    container
    |> Ash.reload!()
    |> Ash.Changeset.for_update(:set_processing, %{}, ash_opts)
    |> Ash.update()
  end

  defp set_ready!(container, ash_opts) do
    container
    |> Ash.reload!()
    |> Ash.Changeset.for_update(:set_ready, %{}, ash_opts)
    |> Ash.update()
  end

  defp set_error!(container, ash_opts) do
    container
    |> Ash.reload!()
    |> Ash.Changeset.for_update(:set_error, %{}, ash_opts)
    |> Ash.update()
  end

  defp sync_drafts(container, drafts, opts, ash_opts) do
    with {:ok, _cleared} <- clear_entities(container, opts, ash_opts),
         {:ok, created} <- create_entities(container, drafts, opts, ash_opts) do
      {:ok, created}
    end
  end

  defp clear_entities(container, _opts, ash_opts) do
    container
    |> Ash.reload!()
    |> Ash.Changeset.for_update(:clear, %{}, ash_opts)
    |> Ash.update()
  end

  defp create_entities(container, drafts, opts, ash_opts) when is_list(drafts) do
    created =
      drafts
      |> Enum.map(fn draft ->
        case create_entity(container, draft, opts, ash_opts) do
          {:ok, rec} ->
            rec

          {:error, error} ->
            Logger.warning(fn ->
              {"Crawler: Could not create entity", error: inspect(error)}
            end)

            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, created}
  end

  defp create_entity(container, draft, opts, ash_opts) do
    entity_resource = Keyword.fetch!(opts, :entity_resource)
    entity_foreign_key = Keyword.fetch!(opts, :entity_foreign_key)

    draft_map = Map.from_struct(draft)

    attrs =
      draft_map
      |> Map.put(entity_foreign_key, container.id)

    entity_resource
    |> Ash.Changeset.for_create(:create, attrs, ash_opts)
    |> Ash.create()
  end

  defp ensure_required_opts(opts) do
    with {:ok, _} <- ensure_opt(opts, :entity_resource),
         {:ok, _} <- ensure_opt(opts, :entity_foreign_key) do
      :ok
    end
  end

  defp ensure_opt(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, val} when not is_nil(val) -> {:ok, val}
      _ -> {:error, "Missing required option: #{inspect(key)}"}
    end
  end
end
