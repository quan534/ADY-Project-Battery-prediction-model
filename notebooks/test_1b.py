from ydata_profiling import ProfileReport
import pandas as pd

# Đọc file dữ liệu và gán vào biến cyc (thay đường dẫn cho đúng với file của bạn)
cyc = pd.read_parquet('data/processed/cycles.parquet')

# Sau đó mới chạy các đoạn code tiếp theo
sample = cyc.sample(min(20000, len(cyc)), random_state=42)
ProfileReport(sample, minimal=True).to_file('report/profile.html')
cyc.describe(include='all').T.to_csv('report/table_describe_raw.csv')