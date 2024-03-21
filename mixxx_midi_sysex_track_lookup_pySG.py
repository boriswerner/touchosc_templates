#PySimpleGUI Version - discontinued due to pro licensing, replaced by customtkinter version

import mido
import mido.backends.rtmidi

import os
import sqlite3
import PySimpleGUI as sg
from time import time
from pythonosc import udp_client, dispatcher, osc_server, osc_message_builder, osc_bundle_builder

import select
import socket
from threading import Thread

class CustomSimpleUDPClient(udp_client.SimpleUDPClient):
    def __init__(self, address: str, port: int, allow_broadcast: bool = False) -> None:
        super().__init__(address, port, allow_broadcast)
        self._sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self._sock.bind(('', 0))
        self.client_port = self._sock.getsockname()[1]

DEBUG_ACTIVE = True
CONFIG_FILE = "config.cfg"
midi_input_port = None
database_file = None
osc_tosc_client = None
osc_thread = None
stop_threads = False

deck1_fileduration = None
deck1_filekey = None
deck1_filebpm = None
deck1_trackinfo = None
deck2_fileduration = None
deck2_filekey = None
deck2_filebpm = None
deck2_trackinfo = None

def debug_print(message):
    if DEBUG_ACTIVE:
        print(message)

def save_config(file_path=None, autostartosc=None, osc_tosc_server_address=None, osc_tosc_server_port=None, osc_server_port=None, midi_input_device=None):
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), CONFIG_FILE)
    debug_print(f"Saving config file: {config_path}")

    # Read existing config file
    existing_config = load_config()
    
    # Update values with provided parameters
    if file_path is not None:
        existing_config['file_path'] = file_path
    if autostartosc is not None:
        existing_config['autostartosc'] = autostartosc
    if osc_tosc_server_address is not None:
        existing_config['osc_tosc_server_address'] = osc_tosc_server_address
    if osc_tosc_server_port is not None:
        existing_config['osc_tosc_server_port'] = osc_tosc_server_port
    if osc_server_port is not None:
        existing_config['osc_server_port'] = osc_server_port
    if midi_input_device is not None:
        existing_config['midi_input_device'] = midi_input_device

    # Write the entire updated configuration back to the file
    with open(config_path, 'w') as config_file:
        for key, value in existing_config.items():
            config_file.write(f"{key}={value}\n")

def load_config():
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), CONFIG_FILE)
    debug_print(f"Loading config file: {config_path}")

    # Read existing config file
    existing_config = {}
    if os.path.exists(config_path):
        with open(config_path, 'r') as existing_config_file:
            for line in existing_config_file:
                key, value = line.strip().split('=')
                existing_config[key.strip()] = value.strip()

    return existing_config

# wait for required trackinfo to be complete (separate sysex messages for duration, bpm and key are being sent from mixxx)
#TODO: consolidate deck1 & deck2, e.g. into an array / list / obejct
def collect_track_info(deck_number, fileduration, filekey, filebpm):
    global deck1_fileduration
    global deck1_filekey
    global deck1_filebpm
    global deck1_trackinfo
    global deck2_fileduration
    global deck2_filekey
    global deck2_filebpm
    global deck2_trackinfo
    
    if(deck_number == 1):
        if fileduration is not None:
            deck1_fileduration = fileduration
            debug_print("setting deck 1 fileduration")
        if filekey is not None:
            deck1_filekey = filekey
            debug_print("setting deck 1 filekey")
        if filebpm is not None:
            deck1_filebpm = filebpm
            debug_print("setting deck 1 filebpm")
        if deck1_fileduration and deck1_filekey and deck1_filebpm:
            deck1_trackinfo = query_database(deck1_fileduration, deck1_filebpm, deck1_filekey)
            osc_value = ""
            for artist,title in deck1_trackinfo:
                osc_value = osc_value + artist + " - " + title + "\n"
            send_osc_message("/deck1_trackinfo", osc_value[:-1])
            deck1_fileduration = None
            deck1_filekey = None
            deck1_filebpm = None
        else:
            debug_print("not complete info")

    
    if(deck_number == 2):
        if fileduration is not None:
            deck2_fileduration = fileduration
        if filekey is not None:
            deck2_filekey = filekey
        if filebpm is not None:
            deck2_filebpm = filebpm
        if deck2_fileduration and deck2_filekey and deck2_filebpm:
            deck2_trackinfo = query_database(deck2_fileduration, deck2_filebpm, deck2_filekey)
            osc_value = ""
            for artist,title in deck2_trackinfo:
                osc_value = osc_value + artist + " - " + title + "\n"
            send_osc_message("/deck2_trackinfo", osc_value[:-1])
            deck2_fileduration = None
            deck2_filekey = None
            deck2_filebpm = None
        else:
            debug_print("not complete info")

# Function to process MIDI messages (implementation of Trackdata_out_via_sysex messages: https://github.com/Andymann/mixxx-controllers)
def process_midi_message(message):
    msgbytearray = message.bin()

    #if(msgbytearray[0] == 0xF0 and msgbytearray[1] == 0x7F):
        #debug_print('sysex mixxx')
    index = 2
    loop_condition = True
    NOTENAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B", "Cm", "C#m", "Dm", "D#m", "Em", "Fm", "F#m", "Gm", "G#m", "Am", "A#m", "Bm"]
  
    while loop_condition:
        
        if msgbytearray[index] == 0x01 and (msgbytearray[index+1] == 0x11 or msgbytearray[index+1] == 0x12 or msgbytearray[index+1] == 0x10):
            #print("bpm")
            #bpm_deck = "".join(map(str, msgbytearray[index+2:index+7]))
            #if msgbytearray[index+1] == 0x11:
                #print("Deck 1 BPM:", bpm_deck)
            #elif msgbytearray[index+1] == 0x12:
                #print("Deck 2 BPM:", bpm_deck)
            index += 7
        
        elif msgbytearray[index] == 0x01 and (msgbytearray[index+1] == 0x21 or msgbytearray[index+1] == 0x22 or msgbytearray[index+1] == 0x20):
            #print("key")
            #key = NOTENAMES[msgbytearray[index+2]]
            #if msgbytearray[index+1] == 0x21:
                #print("Deck 1 Key:", key)
            #elif msgbytearray[index+1] == 0x22:
                #print("Deck 2 Key:", key)
            index += 3
        
        elif msgbytearray[index] == 0x01 and (msgbytearray[index+1] == 0x31 or msgbytearray[index+1] == 0x32 or msgbytearray[index+1] == 0x30):
            #print("isplaying", msgbytearray[index+2])
            #if msgbytearray[index+1] == 0x31:
                #if msgbytearray[index+2] == 0x01:                    
                    #print("Deck 1 is playing")
                #else:                   
                    #print("Deck 1 is not playing")
            #elif msgbytearray[index+1] == 0x32:
                #if msgbytearray[index+2] == 0x01:                   
                    #print("Deck 2 is playing")
                #else:                   
                    #print("Deck 2 is not playing")
            index += 3
        
        elif msgbytearray[index] == 0x01 and (msgbytearray[index+1] == 0x41 or msgbytearray[index+1] == 0x42 or msgbytearray[index+1] == 0x40):
            #print("crossfader", msgbytearray[index+2])
            index += 3
        
        elif msgbytearray[index] == 0x02 and (msgbytearray[index+1] == 0x11 or msgbytearray[index+1] == 0x12 or msgbytearray[index+1] == 0x10):
            duration = int("".join(map(str, msgbytearray[index+2:index+7])))
            if duration < 3600:
                duration_string = "{:02d}:{:02d}".format(duration // 60 % 60, duration % 60)
            else:
                duration_string = "{:02d}:{:02d}:{:02d}".format(duration // (60 * 60), duration // 60 % 60, duration % 60)
            if msgbytearray[index+1] == 0x11:
                print("Deck 1 duration:", duration_string)
                collect_track_info(1, duration, None, None)
            elif msgbytearray[index+1] == 0x12:
                print("Deck 2 duration:", duration_string)
                collect_track_info(2, duration, None, None)
            index += 7
        
        elif msgbytearray[index] == 0x02 and (msgbytearray[index+1] == 0x21 or msgbytearray[index+1] == 0x22 or msgbytearray[index+1] == 0x20):
            print("filebpm")
            filebpm = round(int("".join(map(str, msgbytearray[index+2:index+7])))/100.0,1)
            if msgbytearray[index+1] == 0x21:
                print("Deck 1 filebpm:", filebpm)
                collect_track_info(1, None, None, filebpm)
            elif msgbytearray[index+1] == 0x22:
                print("Deck 2 filebpm:", filebpm)
                collect_track_info(2, None, None, filebpm)
            index += 7
        
        elif msgbytearray[index] == 0x02 and (msgbytearray[index+1] == 0x31 or msgbytearray[index+1] == 0x32 or msgbytearray[index+1] == 0x30):
            print("filekey")
            print(msgbytearray[index+2])
            filekey = NOTENAMES[msgbytearray[index+2]-1]
            print(msgbytearray[index+1])
            if msgbytearray[index+1] == 0x31:
                print("Deck 1 filekey:", filekey)
                collect_track_info(1, None, filekey, None)
            elif msgbytearray[index+1] == 0x32:
                print("Deck 2 filekey:", filekey)
                collect_track_info(2, None, filekey, None)
            index += 3
        
        elif msgbytearray[index] == 0x02 and (msgbytearray[index+1] == 0x41 or msgbytearray[index+1] == 0x42 or msgbytearray[index+1] == 0x40):
            #print("color")
            #color = "".join(map(str, msgbytearray[index+2:index+10]))
            #print("Color:", color)
            index += 10
        
        else:
            loop_condition = False
            break
        
        if loop_condition and msgbytearray[index] == 0x7F:
            loop_condition = True
            index += 1
        else:
            loop_condition = False

        

# Function to query the mixx SQLite database to retrieve artist & title based on duration, bpm and key (duplicates might happen)
def query_database(duration, bpm, key):
    global database_file
    connection = sqlite3.connect(database_file)
    cursor = connection.cursor()
    
    query = f"""
        SELECT artist, title
        FROM library
        WHERE CAST(duration as INTEGER) = {duration}
        AND ROUND(bpm, 1) = {bpm}
        AND key = '{key}'
        group by artist, title
    """
    debug_print(query)
    cursor.execute(query)
    results = cursor.fetchall()
    
    connection.close()

   # Extract title and artist from query results
    #titles_artists = [(result[0], result[1]) for result in results]
    
    debug_print(results)
    return results


# method to get primary IP adress of the PC (source: https://stackoverflow.com/questions/166506/finding-local-ip-addresses-using-pythons-stdlib)
def get_ip():
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0)
        try:
            # doesn't even have to be reachable
            s.connect(('10.254.254.254', 1))
            IP = s.getsockname()[0]
        except Exception:
            IP = '127.0.0.1'
        finally:
            s.close()
        return IP
    
# Function to send OSC message
def send_osc_message(address, value):
    global osc_tosc_client
    debug_print("send_osc_message address")
    debug_print(address)
    debug_print("send_osc_message value")
    debug_print(value)

    osc_tosc_client.send_message(address, value)
         
def connect_to_osc_server(osc_server_address, osc_server_port):
    global osc_tosc_client
    try:
        client = CustomSimpleUDPClient(osc_server_address, osc_server_port)
        debug_print(f"Connected to OSC server: {osc_server_address}:{osc_server_port}")
        return client
    except Exception as e:
        sg.popup_error(f"Error connecting to OSC server:\n{e}")
        return None
    
def receive_osc_message(addr, *args):
    debug_print(f"Received OSC message: {addr} {args}")
    
def start_osc_server(host, port):
    dispatcher = osc_server.Dispatcher()
    dispatcher.set_default_handler(receive_osc_message)
    global stop_threads
    stop_threads = False
    server = osc_server.ThreadingOSCUDPServer((host, port), dispatcher)

    debug_print(f"OSC Server listening on port {port}")

    while not stop_threads:
        # Use select to handle requests with a timeout
        readable, _, _ = select.select([server.socket], [], [], 1.0)
        if readable:
            server.handle_request()

    server.server_close()
    debug_print("OSC Server stopped.")


def start_osc_server_in_thread(host, port):
    global osc_thread
    osc_thread = Thread(target=start_osc_server, args=[host, port])
    osc_thread.start()
    return osc_thread

def main():
    
    config = load_config()
    global midi_input_port
    global database_file
    global osc_thread
    global stop_threads
    global osc_tosc_client
    # GUI layout
    layout = [
        [sg.Text("Select MIDI Device:"), sg.DropDown(values=mido.get_input_names(), key='-MIDIDEVICE-', default_value=config['midi_input_device']),
            sg.Button("Start MIDI Receiving", key='-STARTMIDI-'), sg.Button("Stop MIDI", key='-STOPMIDI-')],
        [sg.Text("Select SQLite Database:"), sg.InputText(key='-FILE-', default_text=config['file_path']), sg.FileBrowse()],
        [sg.Text("OSC Host:"), sg.InputText(key='-OSCTOSCSERVERADDR-', default_text=config['osc_tosc_server_address'])],
        [sg.Text("OSC Send Port:"), sg.InputText(key='-OSCTOSCSERVERPORT-', default_text=config['osc_tosc_server_port'])],
        [sg.Text("OSC Receive Port:"), sg.InputText(key='-OSCSERVERPORT-', default_text=config['osc_server_port'])],
        [sg.Checkbox('Start OSC on program startup', key='-AUTOSTARTOSC-', default=config['autostartosc'])],
        [sg.Button("Start OSC", key='-STARTOSC-'), sg.Button("Send OSC TEST Message", key='SEND_OSC')],
        [sg.Button("Test Database Query", key='test_query')],
    ]

    window = sg.Window("MIDI & OSC Control", layout)
    # OSC setup
    if(config['autostartosc']):
        if config['osc_tosc_server_address'] and config['osc_tosc_server_port']:
            osc_tosc_client = connect_to_osc_server(config['osc_tosc_server_address'], int(config['osc_tosc_server_port']))
        if config['osc_server_port']:
            osc_thread = start_osc_server_in_thread(get_ip(), int(config['osc_server_port']))

    # Main event loop
    while True:
        event, values = window.read()

        if(midi_input_port):
            for msg in midi_input_port.iter_pending():
                print(msg)

        if event in (sg.WIN_CLOSED, 'Exit'):
            debug_print("Exiting the program")
            stop_threads = True  # Set the stop flag to signal the OSC thread to stop
            if osc_thread:
                osc_thread.join()  # Wait for the OSC thread to finish

            break
        elif event == '-STARTMIDI-':
            #TODO: check if midi device is existing and available (error handling), add to autostart option
            if values['-MIDIDEVICE-'] and values['-FILE-']:
                debug_print('Starting MIDI...')
                midi_input_port = mido.open_input(values['-MIDIDEVICE-'])
                midi_input_port.callback = process_midi_message
                database_file = values['-FILE-']
                save_config(database_file, None, None, None, None, values['-MIDIDEVICE-'])
            else:
                sg.popup("Please select both MIDI device and SQLite database.")
        elif event == 'SEND_OSC':
            osc_tosc_client.send_message("/deck1_trackinfo", r"TEST \n Newline \r Return \r\n RN")
            #send_osc_message("/deck1_trackinfo", "TEST \n Newline\rReturn\r\nRN")
        elif event == 'test_query':
            database_file = values['-FILE-']
            save_config(database_file, None, None, None, None, None)
            query_database(173, 152.0, 'A')
        elif event == '-STOPMIDI-':
            if(midi_input_port):
                debug_print('Stopping MIDI...')
                midi_input_port.close()
        elif event == '-STARTOSC-':
            if values['-OSCTOSCSERVERADDR-'] and values['-OSCTOSCSERVERPORT-'] and values['-OSCSERVERPORT-']:
                autostartosc = values['-AUTOSTARTOSC-']
                osc_tosc_server_address = values['-OSCTOSCSERVERADDR-']
                osc_tosc_server_port = values['-OSCTOSCSERVERPORT-']
                osc_server_port = values['-OSCSERVERPORT-']
                debug_print(f"Saved osc_tosc_server_address: {osc_tosc_server_address}")
                debug_print(f"Saved osc_tosc_server_port: {osc_tosc_server_port}")
                save_config(None, autostartosc, osc_tosc_server_address, osc_tosc_server_port, osc_server_port, None)
                if osc_tosc_server_address and osc_tosc_server_port:
                    osc_tosc_client = connect_to_osc_server(osc_tosc_server_address, int(osc_tosc_server_port))

                #TODO: server not used at the moment as no respone is required
                # Start OSC server in a separate thread
                #osc_server_host = get_ip()
                #if osc_thread:
                #    osc_thread.join()  # Wait for the previous OSC thread to finish
                #osc_thread = start_osc_server_in_thread(osc_server_host, int(osc_server_port))
            else:
                sg.popup("Please enter OSC host, send port, and receive port.")
    window.close()


if __name__ == "__main__":
    main()