# Step 1b: convert NASA PCoE .mat files into two tables (Fixed PyArrow Version)
import glob
from pathlib import Path
import numpy as np
import pandas as pd
from scipy.io import loadmat

meas, cyc = [], []

for f in glob.glob('data/raw/B00*.mat'):
  name = Path(f).stem
  mat_data = loadmat(f, simplify_cells=True)

  # Đọc key chứa dữ liệu chu kỳ
  if name in mat_data:
    m = mat_data[name]['cycle']
  else:
    keys = [k for k in mat_data.keys() if not k.startswith('__')]
    m = mat_data[keys[0]]['cycle']

  for k, c in enumerate(m):
    if c['type'] != 'discharge':
      continue
    d = c['data']

    # 1. Trích xuất Capacity an toàn (tránh lỗi mảng numpy rỗng)
    cap = d.get('Capacity', np.nan)
    if isinstance(cap, np.ndarray):
      cap = cap.item() if cap.size == 1 else (cap[0] if cap.size > 0 else np.nan)

    # 2. Trích xuất Nhiệt độ môi trường (T_amb) an toàn
    t_amb = c.get('ambient_temperature', np.nan)
    if isinstance(t_amb, np.ndarray):
      t_amb = (
          t_amb.item()
          if t_amb.size == 1
          else (t_amb[0] if t_amb.size > 0 else np.nan)
      )

    meas.append(
        pd.DataFrame({
            'cell': name,
            'cycle': k,
            't': d['Time'],
            'V': d['Voltage_measured'],
            'I': d['Current_measured'],
            'T': d['Temperature_measured'],
        })
    )
    cyc.append({
        'cell': name,
        'cycle': k,
        'capacity': cap,
        'T_amb': t_amb,
    })

meas = pd.concat(meas, ignore_index=True)
cyc = pd.DataFrame(cyc)

# Ép kiểu dữ liệu chuẩn số thực (float64) cho PyArrow trước khi lưu Parquet
cyc['capacity'] = pd.to_numeric(cyc['capacity'], errors='coerce')
cyc['T_amb'] = pd.to_numeric(cyc['T_amb'], errors='coerce')

# Lưu thành các file Parquet
meas.to_parquet('data/processed/meas.parquet')
cyc.to_parquet('data/processed/cycles.parquet')

print(
    'Thành công! Kích thước meas:',
    meas.shape,
    '| Kích thước cyc:',
    cyc.shape,
    '| Số lượng pin:',
    cyc.cell.nunique(),
)