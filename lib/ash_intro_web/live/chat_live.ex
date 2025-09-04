defmodule AshIntroWeb.ChatLive do
  use AshIntroWeb, :live_view
  on_mount {AshIntroWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"conversation_id" => conversation_id}, _url, socket) do
    conversation =
      case AshIntro.Chat.get_conversation(conversation_id, actor: socket.assigns.current_user) do
        {:ok, conversation} -> conversation
        _ -> nil
      end

    AshIntroWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")

    socket =
      socket
      |> assign(conversation: conversation)
      |> stream(:messages, AshIntro.Chat.message_history!(conversation.id, stream?: true))
      |> assign_message_form()

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      socket
      |> assign(conversation: nil)
      |> stream(:messages, [])
      |> assign_message_form()

    {:noreply, socket}
  end

  defp assign_message_form(socket) do
    form =
      if socket.assigns.conversation do
        AshIntro.Chat.form_to_create_message(
          actor: socket.assigns.current_user,
          private_arguments: %{conversation_id: socket.assigns.conversation.id}
        )
        |> to_form()
      else
        AshIntro.Chat.form_to_create_message(actor: socket.assigns.current_user)
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
  end

  @impl true
  def handle_event("validate-message", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :message_form, AshPhoenix.Form.validate(socket.assigns.message_form, params))}
  end

  @impl true
  def handle_event("submit-message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form, params: params) do
      {:ok, message} ->
        if socket.assigns.conversation do
          socket
          |> assign_message_form()
          |> stream_insert(:messages, message, at: 0)
          |> then(&{:noreply, &1})
        else
          {:noreply,
           socket
           |> push_navigate(to: ~p"/chat/#{message.conversation_id}")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :message_form, form)}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          payload: message
        },
        socket
      ) do
    {:noreply, stream_insert(socket, :messages, message, at: 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col-reverse flex-grow overflow-clip">
        <div>
          <.form
            id="message-form"
            for={@message_form}
            phx-change="validate-message"
            phx-submit="submit-message"
            class="flex items-center px-1.5 pt-3 pb-1 border-t border-t-slate-300"
            onsubmit="chatScroller.scrollTop = chatScroller.scrollHeight"
          >
            <.textarea message_form={@message_form} />
            <.submit_button />
          </.form>
          <div class="flex flex-wrap items-center justify-center pt-1 pb-2 gap-2 text-xs ">
            <.link :if={@conversation} navigate={~p"/"} id="new-chat-link" class="btn btn-xs">
              <.icon name="hero-plus-circle" /> New Chat
            </.link>
            <.link
              navigate={
                if @conversation, do: ~p"/chat/#{assigns.conversation.id}/events", else: ~p"/events/"
              }
              id="new-chat-link"
              class="btn btn-xs"
            >
              <.icon name="hero-calendar-days" /> Events
            </.link>
            <span class="w-full sm:w-auto text-center">
              This is a chat bot. Please check important information.
            </span>
          </div>
        </div>
        <div
          id="chatScroller"
          class="flex flex-col-reverse flex-grow px-2 py-4 overflow-auto"
        >
          <ul
            role="list"
            id="chat-messages"
            class="flex flex-col-reverse gap-3"
            phx-update="stream"
          >
            <%= for {dom_id, message} <- @streams.messages do %>
              <.message
                dom_id={dom_id}
                message={message}
              />
            <% end %>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp textarea(assigns) do
    ~H"""
    <textarea
      class="flex-grow px-3 py-1.5 border-1 border-solid border-slate-300 min-h-10 rounded-3xl mx-1 resize-none"
      aria-label="Write your message"
      style="field-sizing: content;"
      id="chat-message-textarea"
      name={@message_form[:text].name}
      placeholder="Ask anything"
      phx-hook="ChatInput"
      phx-debounce="200"
    ><%= Phoenix.HTML.Form.normalize_value("textarea", @message_form[:text].value) %></textarea>
    """
  end

  defp submit_button(assigns) do
    ~H"""
    <button
      class="shrink-0 w-10 h-10 flex items-center bg-primary text-white justify-center rounded-full rounded disabled:opacity-50 disabled:cursor-not-allowed transition duration-300"
      aria-label="Nachricht senden"
    >
      <.icon name="hero-paper-airplane" class="translate-x-px size-5" />
    </button>
    """
  end

  attr :dom_id, :string, required: true
  attr :message, AshIntro.Chat.Message, required: true

  defp message(%{message: %{source: :user}} = assigns) do
    ~H"""
    <li id={@dom_id} class="chat chat-end">
      <div class="chat-bubble">
        <.markdown text={@message.text} />
      </div>
    </li>
    """
  end

  defp message(%{message: %{source: :agent}} = assigns) do
    ~H"""
    <li id={@dom_id} class="chat chat-start">
      <div class="chat-bubble">
        <.markdown text={@message.text} />
      </div>
    </li>
    """
  end
end
