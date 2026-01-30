#!/usr/bin/env python3
"""Claude Terminal API Server - Provides HTTP REST API for Claude CLI"""
import asyncio, json, logging, os, sys, time
from pathlib import Path
from typing import Dict, Any, Optional
import aiohttp.web

DEFAULT_TIMEOUT, MAX_TIMEOUT, MAX_PROMPT_LENGTH = 300, 600, 50000
START_TIME = time.time()

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

def setup_environment():
    for k, v in {'HOME': '/data/home', 'ANTHROPIC_CONFIG_DIR': '/data/.config/claude',
                 'XDG_CONFIG_HOME': '/data/.config', 'XDG_CACHE_HOME': '/data/.cache',
                 'XDG_STATE_HOME': '/data/.local/state', 'XDG_DATA_HOME': '/data/.local/share'}.items():
        os.environ[k] = v
    logger.info(f"Environment: HOME={os.environ['HOME']}, ANTHROPIC_CONFIG_DIR={os.environ['ANTHROPIC_CONFIG_DIR']}")

def load_config() -> Dict[str, Any]:
    try:
        return json.load(open('/data/options.json'))
    except:
        return {'api_enabled': True, 'api_timeout': DEFAULT_TIMEOUT}

async def check_claude_available() -> bool:
    try:
        p = await asyncio.create_subprocess_shell('which claude', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        await p.communicate()
        return p.returncode == 0
    except:
        return False

async def run_claude(prompt: str, timeout: int, model: Optional[str]) -> Dict:
    start = time.time()
    cmd = ['claude', '-p', prompt]
    if model: cmd.extend(['--model', model])
    logger.info(f"Running: {cmd[0]} {cmd[1]} '{prompt[:50]}...'")
    try:
        p = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE, 
                                                   stderr=asyncio.subprocess.PIPE, env=os.environ)
        try:
            out, err = await asyncio.wait_for(p.communicate(), timeout=timeout)
            t = round(time.time() - start, 2)
            if p.returncode == 0:
                return {'success': True, 'output': out.decode('utf-8').strip(), 
                        'execution_time': t, 'model': model or 'default'}
            return {'success': False, 'error': err.decode('utf-8').strip() or 'Failed', 
                    'error_type': 'execution', 'exit_code': p.returncode}
        except asyncio.TimeoutError:
            p.kill()
            await p.wait()
            return {'success': False, 'error': f'Timeout after {timeout}s', 'error_type': 'timeout'}
    except FileNotFoundError:
        return {'success': False, 'error': 'Claude CLI not found', 'error_type': 'execution'}
    except Exception as e:
        return {'success': False, 'error': str(e), 'error_type': 'internal'}

async def handle_claude(req):
    try:
        data = await req.json()
        prompt = data.get('prompt')
        if not prompt or not isinstance(prompt, str) or not prompt.strip():
            return aiohttp.web.json_response({'success': False, 'error': 'Invalid prompt', 
                                              'error_type': 'validation'}, status=400)
        if len(prompt) > MAX_PROMPT_LENGTH:
            return aiohttp.web.json_response({'success': False, 'error': 'Prompt too long',
                                              'error_type': 'validation'}, status=400)
        opts = data.get('options', {})
        timeout = min(int(opts.get('timeout', req.app['config'].get('api_timeout', DEFAULT_TIMEOUT))), MAX_TIMEOUT)
        result = await run_claude(prompt, timeout, opts.get('model'))
        return aiohttp.web.json_response(result, status=200 if result['success'] else 
                                         (504 if result.get('error_type') == 'timeout' else 500))
    except:
        return aiohttp.web.json_response({'success': False, 'error': 'Invalid request', 
                                          'error_type': 'validation'}, status=400)

async def handle_health(req):
    return aiohttp.web.json_response({'status': 'ok',
                                      'claude_available': await check_claude_available(),
                                      'uptime': round(time.time() - START_TIME, 2)})

async def handle_root(req):
    return aiohttp.web.json_response({'message': 'Claude Terminal API',
                                      'endpoints': {'POST /api/claude': 'Execute', 'GET /api/health': 'Status'}})

def main():
    logger.info("="*60)
    logger.info("Claude Terminal API Server")
    logger.info("="*60)
    setup_environment()
    config = load_config()
    if not config.get('api_enabled', True):
        logger.warning("API disabled")
        return
    app = aiohttp.web.Application()
    app['config'] = config
    app.router.add_post('/api/claude', handle_claude)
    app.router.add_get('/api/health', handle_health)
    app.router.add_get('/', handle_root)
    logger.info(f"Starting on 0.0.0.0:7682, timeout={config.get('api_timeout', DEFAULT_TIMEOUT)}s")
    aiohttp.web.run_app(app, host='0.0.0.0', port=7682, print=None, access_log=None)

if __name__ == '__main__':
    main()
