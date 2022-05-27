import sys
import os
import getopt
import requests
import datetime
import time

def mk_lines(token, base_tag, block):
    tag = base_tag+":"+str(block)
    lines = token + "\r\n" + "#insert:"+tag+"\r\n"
    # print(lines)
    return lines

from time import sleep

#
#
#
def send_file_in_direct_order(fname, base_tag, url):
    token = "kzFXyp3fsnSyCmjk@xjVsTw!ef4se"
    MAX_LINES = 900 
    MAX_LENGTH = 60000
    total_lines = 0
    url = url + '/tc/csv/v1'
    dts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(dts, "Sending file:", fname, flush=True) 
    with open(fname) as file:
        n = 0
        sz = 0
        block = 1
        lines = mk_lines(token, base_tag, block)
        for line in file:
            # print("Line:", line) #<<<<<<<<<<<<<<<<<<<
            sz += len(line)
            lines += line
            n += 1
            if n > MAX_LINES or sz > MAX_LENGTH:
                res = requests.post(url, lines)
                
                if res.text[:2] != "ok": 
                    print("  Block Res:",res.text, end="")
                    return total_lines
                block += 1
                lines = mk_lines(token, base_tag, block)
                sz = 0
                total_lines += n
                n = 0
            
            # sleep(0.020)

        if n > 0:
            res = requests.post(url,lines)
            
            if res.text[:2] != "ok": 
                print("  Final Res:",res.text, end="")
                return total_lines
            total_lines += n
    return total_lines

def help():
    print("--------------------------------------------------")
    myself = sys.argv[0]
    
    print(myself);
    print("Scans <base-path> for csv files to send to tinycubes server at <url>.")
    print("--------------------------------------------------")
    print("Usage: " + myself + " url, base-path, [ start_date ].")
    print("\tstart_date: YYYYMMDD")
    sys.exit(1)


pop_id = {
    "ac": "1", "al": "2", "ap": "3", "am": "4", "ba": "5", "ce": "6",
    "es": "7", "go": "8", "ma": "9", "mt": "10", "ms": "11", "mg": "12",
    "pa": "13", "pb": "14", "pr": "15", "pe": "16", "pi": "17", "rj": "18",
    "rn": "19", "rs": "20", "ro": "21", "rr": "22", "sc": "23", "sp": "24",
    "se": "25", "to": "26", "df": "27"
}


def main():
    base_path = '/home/borescope/perfSonar/Atraso e Perda de pacotes/histogram-rtt/'
    file = '20210415_00_00.csv'
    url = 'http://gwrec.cloudnext.rnp.br:60085'

    # args = sys.argv[1:] # o primeiro arg eh o nome do programa
    # if len(args) < 2:
        # help()
    # elif len(args) == 2:
        # url, base_path = args
        # start_date = '00000000'
    # elif len(args) == 3:
        # url, base_path, start_date = args

    end_date = None
    start_date = "00000000"
    url = None
    base_path = None
    
    try:
        opts, args = getopt.getopt(sys.argv[1:],"d:e:p:u:",["time-start=","time-end=","base-path=","url="])
    except getopt.GetoptError as err:
        print(err)
        help()
        
    for opt, arg in opts:
        if opt in ("-d", "--time-start"):
            start_date = arg
        elif opt in ("-e", "--time-end"):
            end_date = arg
        elif opt in ("-p", "--base-path"):
            base_path = arg
        elif opt in ("-u", "--url"):
            url = arg
    
    if base_path is None or url is None:
        print("Missing Argument")
        print("Base Path:", base_path, "Url:", url)
        sys.exit(1)
    
    start_time = time.time() # execution time
    #end_date = '20210915'
        
    # verifica parametros
    
    # varre todos os arquivos do base_path
    dirs0 = base_path
    dates = []
    
    print("Sending to:", url) 
    for item in os.walk(dirs0): # item = (path, dirnames, filenames)
        for fname in sorted(item[2]):
            fdate = fname[:8]
            try:
                d = int(fdate)
            except:
                continue
            if fdate < start_date: continue
            if end_date is not None and fdate > end_date: break
            
            fullfname = item[0] + '/' + fname
            # print(fname + ";" + fullfname)
            dates.append(fname + ";" + fullfname)
            
    rdates = sorted(dates, reverse = True)

    prev_date = ""
    date = ""
    total_lines_sent = 0
    last_total_lines_sent = 0
    
    for i in range(len(rdates)):
        date = rdates[i][:18]
        fullfname = rdates[i][19:]
        # print(i, rdates[i], date)

        total_lines_sent += send_file_in_direct_order(fullfname, fullfname, url)
                
        # oferece 200ms de intervalo
        if total_lines_sent - last_total_lines_sent > 10000:
            sleep(0.050)                
            last_total_lines_sent = total_lines_sent
        
    
    print("--------------------------------")
    print("Done", base_path)
    print("Total Lines Sent:", total_lines_sent)    
    print("--- Executed in %s seconds ---" % (time.time() - start_time))

if __name__ == '__main__':
    main()

