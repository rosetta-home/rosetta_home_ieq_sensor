defmodule Cicada.DeviceManager.Device.IEQ.Sensor do
  use Cicada.DeviceManager.DeviceHistogram
  require Logger
  alias Cicada.{DeviceManager, VoiceControl}
  @behaviour Cicada.DeviceManager.Behaviour.IEQ

  def start_link(id, device) do
    GenServer.start_link(__MODULE__, {id, device}, name: id)
  end

  def set_mode(pid, mode) do
    GenServer.cast(pid, {:set_mode, mode})
  end

  def readings(pid) do
    GenServer.call(pid, :readings)
  end

  def device(pid) do
    GenServer.call(pid, :device)
  end

  def update_state(pid, state) do
    GenServer.call(pid, {:update, state})
  end

  def get_id(device) do
    :"Sensor-#{device.id}"
  end

  def map_state(state) do
    Map.merge(%DeviceManager.Device.IEQ.State{}, state)
  end

  def init({id, device}) do
    #Process.send_after(self, :add_voice_controls, 100)
    {:ok, %DeviceManager.Device{
      module: IEQGateway.IEQStation,
      type: :ieq,
      device_pid: device.id,
      interface_pid: id,
      name: Atom.to_string(device.id),
      state: map_state(device)
    }}
  end

  def handle_info(:add_voice_controls, device) do
    VoiceControl.Client.add_handler("WHAT IS VEEOHSEE", 1)
    VoiceControl.Client.add_handler("WHAT IS HUMIDTY", 2)
    VoiceControl.Client.add_handler("WHAT IS TEMPERATURE", 3)
    {:noreply, device}
  end

  def handle_info({:voice_callback, 1}, device) do
    Logger.info "Got Callback 1"
    VoiceControl.Client.say "#{device.state.voc} pee pee be"
    {:noreply, device}
  end

  def handle_info({:voice_callback, 2}, device) do
    Logger.info "Got Callback 2"
    VoiceControl.Client.say "#{device.state.humidity} percent"
    {:noreply, device}
  end

  def handle_info({:voice_callback, 3}, device) do
    Logger.info "Got Callback 3"
    VoiceControl.Client.say "#{device.state.temperature} degrees"
    {:noreply, device}
  end

  def handle_call({:update, state}, _from, device) do
    state = state |> map_state
    {:reply, state, %DeviceManager.Device{device | state: state}}
  end

  def handle_call(:device, _from, device) do
    {:reply, device, device}
  end

  def handle_call(:readings, _from, device) do
    {:reply, device.state, device}
  end

  def handle_cast({:set_mode, mode}, device) do
    IEQGateway.IEQStation.set_mode(device.device_pid, %IEQGateway.Modes{} |> Map.get(mode))
    {:noreply, device}
  end

end

defmodule Cicada.DeviceManager.Discovery.IEQ.Sensor do
  require Logger
  alias Cicada.DeviceManager.Device.IEQ
  use Cicada.DeviceManager.Discovery, module: IEQ.Sensor

  defmodule EventHandler do
    use GenEvent
    require Logger

    def handle_event(%IEQGateway.IEQStation.State{} = device, parent) do
      send(parent, device)
      {:ok, parent}
    end

    def handle_event(_device, parent) do
      {:ok, parent}
    end

    def terminate(reason, parent) do
      Logger.info "IEQ Sensor EventHandler Terminating: #{inspect reason}"
      :ok
    end

  end

  def register_callbacks do
    [tty] = get_tty()
    Logger.info "Starting IEQ Sensor Listener: #{tty}"
    tty |> IEQGateway.Supervisor.start_link()
    IEQGateway.EventManager.add_handler(EventHandler)
    %{}
  end

  def handle_info(%IEQGateway.IEQStation.State{} = device, state) do
    {:noreply, handle_device(device, state)}
  end

  def handle_info(_device, state) do
    {:noreply, state}
  end

  def get_tty do
    Nerves.UART.enumerate |> Enum.flat_map(fn({tty, device}) ->
      Logger.debug("#{inspect device}")
      case Map.get(device, :product_id, 0) do
        24597 ->
          Logger.debug("Setting IEQ TTY: #{inspect tty}")
          case String.starts_with?(tty, "/dev") do
            true -> [tty]
            false -> ["/dev/#{tty}"]
          end
        _ -> []
      end
    end)
  end
end
