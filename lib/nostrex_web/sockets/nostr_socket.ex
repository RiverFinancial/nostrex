defmodule NostrexWeb.NostrSocket do
	# NOT USING Phoenix.Socket because it requires a proprietary wire protocol that is incompatible with Nostr


	@moduledoc """
	  Simple Websocket handler that echos back any data it receives
	  """

	  @behaviour :cowboy_websocket

	  # entry point of the websocket socket. 
	  # WARNING: this is where you would need to do any authentication
	  #          and authorization. Since this handler is invoked BEFORE
	  #          our Phoenix router, it will NOT follow your pipelines defined there.
	  # 
	  # WARNING: this function is NOT called in the same process context as the rest of the functions
	  #          defined in this module. This is notably dissimilar to other gen_* behaviours.          
	  @impl :cowboy_websocket
	  def init(req, opts), do: {:cowboy_websocket, req, opts}

	  # as long as `init/2` returned `{:cowboy_websocket, req, opts}`
	  # this function will be called. You can begin sending packets at this point.
	  # We'll look at how to do that in the `websocket_handle` function however.
	  # This function is where you might want to  implement `Phoenix.Presence`, schedule an `after_join` message etc.
	  @impl :cowboy_websocket
	  def websocket_init(state), do: {[], state}

	  # `websocket_handle` is where data from a client will be received.
	  # a `frame` will be delivered in one of a few shapes depending on what the client sent:
	  # 
	  #     :ping
	  #     :pong
	  #     {:text, data}
	  #     {:binary, data}
	  # 
	  # Similarly, the return value of this function is similar:
	  # 
	  #     {[reply_frame1, reply_frame2, ....], state}
	  # 
	  # where `reply_frame` is the same format as what is delivered.
	  @impl :cowboy_websocket
	  def websocket_handle(frame, state)

	  # Implement basic ping pong handler for easy health checking
	  def websocket_handle({:text, "ping"}, state), do: {[{:text, "pong"}], state}

	  # a message was delivered from a client. Here we handle it by just echoing it back
	  # to the client.
	  def websocket_handle({:text, message}, state) do
	  	{[{:text, message}], state}
	  end

	  # # This function is where we will process all *other* messages that get delivered to the
	  # # process mailbox. This function isn't used in this handler.
	  @impl :cowboy_websocket
	  def websocket_info(info, state)

	  def websocket_info(_info, state), do: {[], state}
end