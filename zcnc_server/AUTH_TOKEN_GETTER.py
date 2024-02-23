

import asyncio
import aiohttp
import json
import os

async def get_auth_token(username, password):
    # project_id_b64 = encode_uuid_to_b64str(project_id)
    # headers={"Authorization": f"Bearer {AUTH_TOKEN}"}
    body = {
        "username": username,
        "password": password
    }
    # print(f"""Authorizing: {headers}""")
    async with aiohttp.ClientSession(trust_env=True) as session:
        async with session.post(f"http://localhost:9000/api/v2/auth/token", json=body) as response:
            # logger.info(f"""Trying to update story {(await response.text())}""")
            # print(f"""CNC auth token: {await response.text()}""")
            return (await response.json())['token']

def async_to_sync(awaitable):
    loop = asyncio.get_event_loop()
    return loop.run_until_complete(awaitable)
        
username = os.getenv('TAIGA_CNC_LOGIN')
password = os.getenv('TAIGA_CNC_PASSWORD')
print(username, password)

AUTH_TOKEN = None

if username is None:
    AUTH_TOKEN = os.getenv('TAIGA_CNC_AUTH_TOKEN')
else:
    AUTH_TOKEN = async_to_sync(get_auth_token(username, password))


if __name__=='__main__':
    # print(await get_auth_token())
    # print(asyncio.run(get_auth_token()))
    print(AUTH_TOKEN)