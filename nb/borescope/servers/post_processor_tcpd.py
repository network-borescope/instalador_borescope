import socket
import json
import machine_learning as ml
import pandas as pd
import pickle
import threading

HOSTNAME = "127.0.0.1" # "localhost"
SERVER_PORT = 8080
BUFFER_SIZE = 4096
DEFAULT_MODEL = "/isolation-forest"
MODELS = {
    "/isolation-forest": {"loaded_model": None, "model_file": "models/isolation_forest.sav"}
    }


# processa result com tp = 1
def compute_tp1(val:list):
    computed_result = None
    computed_result = val[0]*1000
    return computed_result

# processa result com tp = 2
def compute_tp2(x:list, y:list):
    computed_result_x = []
    computed_result_y = []
    for i in range(len(x)):
        computed_result_x.append(x[i])
        computed_result_y.append(x[i][0] * y[i][0])

    return (computed_result_x,computed_result_y)


###############################################
## Error Function
###############################################
def error(error_desc, to_bytes=False):
    response = '{"id": 0, "tp": 0, "result": ' + error_desc + '}'

    if to_bytes:
        response = response.encode("utf-8") # bytes to be send
    
    return response

###############################################
## Output to Run-length Encoding(rle)
###############################################
def output_to_rle(callable_output):
    rle = []
    count = 0
    actual_val = None
    for item in callable_output:
        val = item[2]
        if actual_val is not None:
            if val == actual_val:
                count += 1
            else:
                elem = [count, val]
                rle.append(elem)
                count = 0
        else:
            actual_val = val
            count += 1

    if count != 0:
        elem = [count, val]
        rle.append(elem)
    
    return rle

###############################################
## Process Received Data
###############################################
def process_data(data_json, model_name, version=None):
    id = data_json["id"]
    tp = data_json["tp"]
    ms = data_json["ms"]
    rle = False
    if "rle" in data_json: rle = True

    if model_name == "/":
        model_name = DEFAULT_MODEL
    if model_name not in MODELS:
        return error('Unknow model ' + model_name + '.')
    
    loaded_model = MODELS[model_name]["loaded_model"]

    # verificar o tp
    # tp = 0: erro
    # tp = 1: "result": [val]
    # tp = 2: "result": { "k": [key], "v": [val] }
    if tp == 0: return data_json # se possui erro, nao sera processado.

    result = data_json["result"]
    response_json = None
    if tp == 1:
        computed_result = compute_tp1(result) # result eh uma lista com um elemento.
        js_result = [computed_result]

    elif tp == 2:
        # x = []
        # y = []
        # for pair in result:
        #     x.append(pair["k"])
        #     y.append(pair["v"])

        # computed_result_x,computed_result_y = compute_tp2(x, y)
        # js_result = []
        # for i in range(len(computed_result_x)): # formatando o resultado
        #     js_result.append({"k": computed_result_x[i], "v": computed_result_y[i]})

        fields = data_json["fields"]

        data_frame = pd.DataFrame.from_dict(data=result, orient='index', columns=fields)
        #print(data_frame)
        js_result = ml.callable(data_frame, loaded_model)
        if rle: js_result = output_to_rle(js_result)

    response_json = {"id": id, "tp": tp, "result": js_result, "ms": ms}
    return response_json


###############################################
## Load Machine Learning Models
###############################################
def load_models(reload=False):
    print("Loading models...")

    for model_item in MODELS.items():
        model = model_item[1]
        if model["loaded_model"] is None or reload:
            model["loaded_model"] = pickle.load(open(model["model_file"], 'rb'))

            print(model_item[0][1:], "Ok.")


###############################################
## Protocol Header Parser
###############################################
def header_parser(str):
    version = ""
    i = 2 # index begins at 2 because str begins with "# "
    
    # must start with version number
    if not ("0" <= str[i] <= "9"):
        return None
    version += str[i]

    i += 1
    while True: # get rest of version number(float)
        if ("0" <= str[i] <= "9") or str[i] == ".":
            version += str[i]
            i += 1
        else:
            break # end of version number
    
    try:
        float(version)
    except ValueError:
        return None
    
    if str[i] != " ":
        return None
    i += 1 # consume whitespace

    # must be "/" to indentify model
    if str[i] != "/":
        return None
    
    while i < len(str):
        if str[i] == "\r":
            i += 1
            if str[i] == "\n":
                return i # end of the HEADER
            else:
                return None
        
        i += 1
    
    return None


###############################################
## Task to be executed by each thread
###############################################
def conn_task(conn, addr, thread_count):
    with conn: # new thread
        print('Connected by', addr, "-> Thread", thread_count)

        # Connection variables
        data = "" # total data received
        header_end = None # header end position
        version = None # protocol version
        model = None # desired model
        buffer_str = None # current string in buffer
        
        while True:
            buffer = conn.recv(BUFFER_SIZE)
            buffer_str = buffer.decode("utf-8")

            if buffer_str[:2] == "# ":
                header_end = header_parser(buffer_str)

                if header_end is None:
                    conn.sendall(error("Header Error. Expected \"# <version> <path>\"", True))
                    break # close connection
                
                _, version, model = buffer_str[:header_end].split(" ") # "# <version> <model>"
                model = model.strip().lower()
                buffer_str = buffer_str[header_end+1:]

            if buffer_str[-4:] == "\r\n\r\n":
                data += buffer_str
                # processing data
                data_json = json.loads(data)
                response_json = process_data(data_json, model, version)

                # sending data
                response_str = json.JSONEncoder().encode(response_json)
                #print("Processed Response:", response_str)
                response_bytes = response_str.encode("utf-8")
                conn.sendall(response_bytes)
                break # close connection

            data += buffer_str

        print("Closed connection with", addr, "-> Thread", thread_count)




if __name__ == "__main__":
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((HOSTNAME, SERVER_PORT))
        s.listen()
        
        load_models()
        print("TCP Server Started!!!")

        queue = [] # [(conn, addr)]

        while True:
            conn, addr = s.accept()
    
            t = threading.Thread(target=conn_task, args=(conn, addr, threading.active_count()))
            t.start()

            


    print("TCP Server stopped.")
