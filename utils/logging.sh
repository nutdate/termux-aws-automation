#!/bin/bash
log_info()    { echo -e "ℹ️  $1"; }
log_success() { echo -e "✅ $1"; }
log_error()   { echo -e "❌ $1" >&2; }
