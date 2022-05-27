from http.server import BaseHTTPRequestHandler, HTTPServer

import socket
import json

hostName = "127.0.0.1"#"localhost"
serverPort = 8080
BUFFER_SIZE = 4096

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

def process_data(data_json):
    id = data_json["id"]
    tp = data_json["tp"]
    ms = data_json["ms"]

    # verificar o tp
    # tp = 0: erro
    # tp = 1: "result": [val]
    # tp = 2: "result": { "k": [key], "v": [val] }
    if tp == 0: return data_json # se possui erro, nao sera processado.

    result = data_json["result"]
    response_json = None
    if tp == 1:
        computed_result = compute_tp1(result) # result eh uma lista com um elemento.

    elif tp == 2:
        x = []
        y = []
        for pair in result:
            x.append(pair["k"])
            y.append(pair["v"])

        computed_result_x,computed_result_y = compute_tp2(x, y)
        js_result = []
        for i in range(len(computed_result_x)): # formatando o resultado
            js_result.append({"k": computed_result_x[i], "v": computed_result_y[i]})

    response_json = {"id": id, "tp": tp, "result": js_result, "ms": ms}
    return response_json


if __name__ == "__main__":
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((hostName, serverPort))
        s.listen()

        while True:
            conn, addr = s.accept()
            data = ""
            with conn:
                print('Connected by', addr)
                while True:
                    buffer = conn.recv(BUFFER_SIZE)
                    if buffer[-4:] == b"\r\n\r\n":
                        data += buffer[:-4].decode("utf-8")
                        # processing data
                        data_json = json.loads(data)
                        response_json = process_data(data_json)

                        # sending data
                        response_str = json.JSONEncoder().encode(response_json)
                        #print("Processed Response:", response_str)
                        response_bytes = response_str.encode("utf-8")
                        conn.sendall(response_bytes)
                        break

                    buffer_str = buffer.decode("utf-8")
                    data += buffer_str

    print("TCP Server stopped.")
