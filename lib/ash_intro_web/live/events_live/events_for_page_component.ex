defmodule AshIntroWeb.EventsLive.EventsForPageComponent do
  use AshIntroWeb, :live_component

  # Forwarded broadcast from parent live view
  def update(%{payload: %{action: action, event: event}}, socket) do
    {:ok, upsert_from_action(socket, action, event)}
  end

  # Update after init, relations not loaded, stream already created
  def update(
        %{event_page: _event_page} = assigns,
        %{assigns: %{streams: %{events: event_stream}}} = socket
      )
      when not is_nil(event_stream) do
    {:ok, socket |> assign(assigns)}
  end

  # Initial init, fully loaded page
  def update(%{event_page: event_page} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:event_count, event_page.event_count)
     |> stream(:events, event_page.events)}
  end

  defp upsert_from_action(socket, :create, ev),
    do: socket |> stream_insert(:events, ev) |> update(:event_count, &(&1 + 1))

  defp upsert_from_action(socket, :update, ev),
    do: stream_insert(socket, :events, ev)

  defp upsert_from_action(socket, :destroy, ev),
    do: socket |> stream_delete(:events, ev) |> update(:event_count, &max(&1 - 1, 0))

  def render(assigns) do
    ~H"""
    <div class="px-4 pb-4">
      <div class="bg-gray-50 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-100">
            <tr>
              <th class="px-3 py-2 text-left font-medium text-gray-700">Event Name</th>
              <th class="px-3 py-2 text-left font-medium text-gray-700">Date</th>
              <th class="px-3 py-2 text-left font-medium text-gray-700">Location</th>
            </tr>
          </thead>
          <tbody
            id={"events-list-#{@event_page.id}"}
            phx-update="stream"
            class="divide-y divide-gray-200"
          >
            <tr :for={{id, event} <- @streams.events} id={id} class="hover:bg-gray-100">
              <td class="px-3 py-2 text-gray-900">{event.name}</td>
              <td class="px-3 py-2 text-gray-600">{format_date(event.event_date)}</td>
              <td class="px-3 py-2 text-gray-600">{event.event_location || "—"}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="mt-2 text-xs text-gray-300 text-center">{@event_count} events in total</div>
    </div>
    """
  end

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%b %d, %Y")
  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%b %d, %Y")

  defp format_date(%NaiveDateTime{} = naive_datetime),
    do: Calendar.strftime(naive_datetime, "%b %d, %Y")

  defp format_date(_), do: "—"
end
