from aiohttp import web
import threading
from threading import Thread
import time
import json

PORT = 7777

global Title_CNC
Title_CNC = {}

async def process_control_cnc(ref, control, state):
    return {
        "ref": ref,
        "control": control,
        "state": state,  # running | pause | idle
        "status": "Accepted"  # Accepted | not accepted
    }

async def control_story_CNC(request):
    project_id = request.match_info['project_id']
    ref = int(request.match_info['ref'])
    control = request.match_info['control']
    
    key = (project_id, ref)
    if not key in CNCs:
        create_cnc(key)
    if   control=='resume':
        CNCs[key].resume()
    elif control=='pause':
        CNCs[key].pause()
    elif control=='stop':
        CNCs[key].stop()

    # Here you can perform any required logic, such as checking permissions
    # ...

    result = await process_control_cnc(ref=ref, control=control, state=CNCs[key].state)
    return web.json_response(result)




async def post_task_CNC(request):
    project_id = request.match_info['project_id']
    ref = int(request.match_info['ref'])
    key = (project_id, ref)
    # print(await request.post())
    # print(await request.post().json())
    data = await request.post()

    if not (('file_name' in data.keys()) and ('estimated_time' in data.keys()) and ('file' in data.keys())):
        return web.HTTPPartialContent(text=f"Keyset {data.keys()} is not full")
    try:
        et = int(data['estimated_time'])
        data = dict(data)
        data['estimated_time'] = et
    except Exception as e:
        print(f'Failed to get posted task: {e}')
        
    # Here you can perform any required logic, such as checking permissions
    # ...
    # TODO make checking better (faster)
    try:
        Title_CNC[(project_id,ref)]['files'].append(data)
    except:
        try:
            Title_CNC[(project_id,ref)]['files'] = []
            Title_CNC[(project_id,ref)]['files'].append(data)
        except:
            create_cnc((project_id,ref))
            Title_CNC[(project_id,ref)]['files'].append(data)
    
        

    print(f"Added file {data['file_name']} with time {data['estimated_time']}")

    # result = await process_post_task_CNC(ref=ref, control='resume')
    result = await process_control_cnc(ref=ref, control='resume', state=CNCs[key].state)
    return web.json_response(result)

# async def get_title_cnc_info():
#     global Title_CNC
#     info = {}
#     for key in Title_CNC:
#         info[key] = {}
#         info[key]['files'] = []
#         for fkey in Title_CNC[key]:
#             f = Title_CNC[key][fkey]
#             info[key]['files'] = {'file_name':f['file_name'],
#                                   'estimated_time':f['estimated_time']}
#     return info

async def get_title_cnc_row_info(key):
    global Title_CNC
    # t = replace_none_with_string(Title_CNC)
    info = {}
    info['files'] = []
    if not key in Title_CNC:
        create_cnc(key)
    for f in Title_CNC[key]['files']:
        info['files'].append({'file_name':f['file_name'],
                         'estimated_time':f['estimated_time']})
    info['progress'] = Title_CNC[key]['progress']
    # info = replace_none_with_string(info)
    if info['progress']['current_file_name'] is None:
        info['progress']['current_file_name'] = ''
    print(info)
    return info

async def get_title_cnc(request):
    project_id = request.match_info['project_id']
    ref = int(request.match_info['ref'])

    # Here you can perform any required logic, such as checking permissions
    # ...

    result = await get_title_cnc_row_info((project_id,ref))
    def custom_json_dumps(obj):
        return json.dumps(obj).replace("'", '"')
    return web.json_response(result, dumps=custom_json_dumps)
    

class CNC:
    ID: str
    file_name: str
    file: str
    # progress: float # [0;1]
    file_time: int
    completed_file_time: int
    state: str
    t: Thread
    def __init__(self, ID):
        self.ID = ID
        self.completed_file_time = 1
        self.file_time = 1
        self.file = ""
        self.file_name = None
        self.state = "idle"
        self.t = Thread(target=self._loop)
        self.t.start()
    
    # Simulation of CNC
    def _loop(self):
        while True:
            time.sleep(1)
            # print(CNCs)
            # print(self.state, self.completed_file_time, self.file_time)
            if self.state == "resumed":
                self.completed_file_time += 1
                if self.completed_file_time >= self.file_time:
                    self.stop()
        
    def start(self, file_name, file, estimated_time=None):
        self.completed_file_time = 0
        self.file_name = file_name
        self.file = file
        if estimated_time is not None:
            self.file_time = estimated_time
        print(f'CNC {self.ID}: started file {self.file_name}')
        self.state = 'resumed'
        
    def pause(self):
        # p = ((self.completed_file_time+1e-10) / (self.file_time+1e-10))
        print(f'CNC {self.ID}: paused on file {self.file_name} with progress {self.completed_file_time}:{self.file_time}')
        self.state = 'paused'
        
    def resume(self):
        if self.file == None:
            print(f'CNC {self.ID}: has nothing to resume')
            self.state = 'idle'
        else:
            # p = ((self.completed_file_time+1e-10) / (self.file_time+1e-10))
            print(f'CNC {self.ID}: resumed on file {self.file_name} with progress {self.completed_file_time}:{self.file_time}')
            self.state = 'resumed'
            
    def stop(self):
        print(f'CNC {self.ID}: stoped file {self.file_name} and started cleaning workspace')
        self.state = "idle"
        self.file_time = 1
        self.completed_file_time = 1
        self.file_name = None
        self.file = None
    
    def get_state(self):
        return self.state

    def __str__(self):
        return f"CNC({self.ID})"
    def __repr__(self):
        return f"CNC({self.ID})"
    

def replace_none_with_string(input_dict):
    """
    Replace None values in a dictionary with the string 'None'.

    Parameters:
    - input_dict (dict): The input dictionary.

    Returns:
    - dict: A new dictionary with None values replaced by the string 'None'.
    """
    # return {key: '"None"' if value is None else value for key, value in input_dict.items()}
    d = {}
    for key in input_dict:
        v = input_dict[key]
        if v is None:
            d[key] = '"None"'
        else:
            d[key] = v
    return v

class CNCcontrol:
    cnc: CNC
    ID: str
    t: Thread
    @property
    def state(self):
        return self.cnc.state
    def __init__(self,key):
        self.cnc = CNC(key)
        self.ID = key
        self.t = Thread(target=self._loop)
        self.t.start()
    def _loop(self):
        global Title_CNC
        while True:
            time.sleep(1)
            if self.cnc.state == "idle":
                if len(Title_CNC[self.ID]['files'])>0:
                    task = Title_CNC[self.ID]['files'].pop(0)
                    self._start(task)
            Title_CNC[self.ID]["progress"] = \
            {
                "remaining_all_time":self._calculate_all_time(),
                "current_file_time":self.cnc.file_time,
                "current_completed_file_time":self.cnc.completed_file_time,
                "current_file_name":self.cnc.file_name,
                "state":self.cnc.state
            }
    def _start(self,task):
        # file_name, file
        self.cnc.start(task['file_name'], task['file'], estimated_time=task['estimated_time'])
    def pause(self):
        self.cnc.pause()
    def stop(self):
        # WARNING many cnc's requieres to clear and prepare it's workspace after stop before next file (i.e. task)
        self.cnc.stop()
        print('stopped')
    def resume(self):
        self.cnc.resume()
        print('resumed')
    def _calculate_all_time(self):
        S = 0
        for task in Title_CNC[self.ID]['files']:
            S += task['estimated_time']
        S += (self._get_current_file_time()-self._get_current_completed_file_time())
        return S
    def _get_current_file_time(self):
        return self.cnc.file_time
    def _get_current_completed_file_time(self):
        return self.cnc.completed_file_time
    def __str__(self):
        return f"CNCcontrol({self.cnc})"
    def __repr__(self):
        return f"CNCcontrol({self.cnc})"
CNCs = {}
# Functions to create and update state of CNC
def create_cnc(key):
    CNCs[key] = CNCcontrol(key)
    Title_CNC[key] = {}
    Title_CNC[key]['files'] = []
    Title_CNC[key]['progress'] = {"remaining_all_time":1,
                                    "current_file_time":1,
                                    "current_completed_file_time":1,
                                    "current_file_name":None,
                                    "state":"resumed"}
    
    


app = web.Application()
app.router.add_get('/projects/{project_id}/stories/{ref}/control/{control}', control_story_CNC)
app.router.add_post('/projects/{project_id}/stories/{ref}/post_task', post_task_CNC)
app.router.add_get('/projects/{project_id}/stories/{ref}/get_title_cnc', get_title_cnc)

if __name__ == "__main__":
    web.run_app(app, port=PORT)