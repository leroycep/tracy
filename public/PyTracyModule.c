#define PY_SSIZE_T_CLEAN
#include "Python.h"

#include <tracy/TracyC.h>

static PyObject * PyTracy_Zone(PyObject *self, PyObject *args) {
  unsigned int line_number;
  const char *source_file_ptr;
  const char *function_name_ptr;

  if (!PyArg_ParseTuple(args, "Iss", &line_number, &source_file_ptr, &function_name_ptr)) {
    return NULL;
  }

  size_t source_file_len = strlen(source_file_ptr);
  size_t function_name_len = strlen(function_name_ptr);

  uint64_t srcloc_id = ___tracy_alloc_srcloc(line_number, source_file_ptr, source_file_len, function_name_ptr, function_name_len);
  TracyCZoneCtx ctx = ___tracy_emit_zone_begin_alloc(srcloc_id, 1);

  return Py_BuildValue("Ii", ctx.id, ctx.active);
}

static PyObject * PyTracy_ZoneEnd(PyObject *self, PyObject *args) {
  PyObject *zone_object;
  if (!PyArg_ParseTuple(args, "O", &zone_object)) {
    return NULL;
  }

  TracyCZoneCtx ctx;
  if (!PyArg_ParseTuple(zone_object, "Ii", &ctx.id, &ctx.active)) {
    return NULL;
  }

  TracyCZoneEnd(ctx);

  Py_INCREF(Py_None);
  return Py_None;
}

static PyObject * PyTracy_Plot(PyObject *self, PyObject *args) {
  const char *plot_name_ptr;
  double value;

  if (!PyArg_ParseTuple(args, "sd", &plot_name_ptr, &value)) {
    return NULL;
  }

  ___tracy_emit_plot(plot_name_ptr, value);

  Py_INCREF(Py_None);
  return Py_None;
}

static PyMethodDef PyTracyMethods[] = {
  {"Zone", PyTracy_Zone, METH_VARARGS, "Starts a zone in tracy"},
  {"ZoneEnd", PyTracy_ZoneEnd, METH_VARARGS, "Ends a zone in tracy"},
  {"Plot", PyTracy_Plot, METH_VARARGS, "Plot a number in the tracy profiler"},
  {NULL, NULL, 0, NULL}        /* Sentinel */  
};

static PyModuleDef PyTracyModule;

PyMODINIT_FUNC
PyInit_PyTracyClient(void) {
  PyTracyModule.m_base.m_init = NULL;
  PyTracyModule.m_base.m_index = 0;
  PyTracyModule.m_base.m_copy = NULL;
    
  PyTracyModule.m_name = "tracy";
  PyTracyModule.m_doc = "Interface to TracyC profiler markup functions.";
  PyTracyModule.m_size = -1;
  PyTracyModule.m_methods = PyTracyMethods;

    
  PyObject *m = PyModule_Create(&PyTracyModule);
  if (m == NULL)
      return NULL;

  return m;
}
