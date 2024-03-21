import PyTracyClient
import inspect
import contextlib
import functools

class Zone:
    def __init__(self):
        frameinfo = inspect.getframeinfo(inspect.stack()[1][0])
        self.zone_context = PyTracyClient.Zone(frameinfo.lineno, frameinfo.filename, frameinfo.function)

    def end(self):
        PyTracyClient.ZoneEnd(self.zone_context)

plot = PyTracyClient.Plot

def profile(function):
    @functools.wraps(function)
    def wrapper(*args, **kwargs):
        zone_context = PyTracyClient.Zone(function.__code__.co_firstlineno, function.__code__.co_filename, function.__name__)
        function_return_value = function(*args, **kwargs)
        PyTracyClient.ZoneEnd(zone_context)
        return function_return_value
    return wrapper
