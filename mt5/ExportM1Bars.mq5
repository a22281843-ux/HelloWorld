//+------------------------------------------------------------------+
//|                                                ExportM1Bars.mq5  |
//|  1분봉(M1) 시세를 CSV로 저장하는 스크립트                         |
//|  - 웹 백테스트(빠른 검증)용 DATE,TIME,OPEN,HIGH,LOW,CLOSE 형식   |
//|  - 차트에 끌어다 놓으면 한 번 실행되고 끝납니다 (주문 없음)      |
//|  - 시간은 MT5 서버 시간 그대로 (웹 도구가 한국 시간으로 표시)    |
//+------------------------------------------------------------------+
#property copyright "Trade Desk"
#property version   "1.00"
#property description "1분봉 시세를 CSV로 저장 (MQL5\\Files)"
#property script_show_inputs

input int    InpMonths = 7;   // 내보낼 기간(개월) — 6개월 분석 + 지표 준비 1개월
input string InpSymbol = "";  // 종목 (비우면 현재 차트 종목)

void OnStart()
  {
   string sym = (InpSymbol == "") ? _Symbol : InpSymbol;
   if(!SymbolSelect(sym, true))
     {
      Alert("종목을 찾을 수 없습니다: ", sym);
      return;
     }
   // 진행 중인 봉은 빼고, 마감된 1분봉까지만
   datetime now = iTime(sym, PERIOD_M1, 0);
   if(now == 0)
     {
      Alert("1분봉 데이터를 불러오지 못했습니다. 1분 차트를 한 번 열어 데이터를 받은 뒤 다시 실행하세요.");
      return;
     }
   MqlDateTime d;
   TimeToStruct(now, d);
   int months = MathMax(1, InpMonths);
   d.mon -= months;
   while(d.mon <= 0)
     {
      d.mon += 12;
      d.year--;
     }
   d.day = 1;
   d.hour = 0;
   d.min = 0;
   d.sec = 0;
   datetime from = StructToTime(d);

   MqlRates r[];
   ArraySetAsSeries(r, false);
   int n = CopyRates(sym, PERIOD_M1, from, now - 60, r);
   if(n <= 0)
     {
      Alert("1분봉을 가져오지 못했습니다 (", GetLastError(), "). 도구 → 옵션 → 차트의 '차트의 최대 바 수'를 늘려 보세요.");
      return;
     }
   int start = 0;
   if(n > 250000)
     {
      start = n - 250000; // 웹 도구 최대 25만 봉
      Print("ExportM1: 25만 봉을 넘어 최근 25만 봉만 저장합니다. 기간을 줄이면 전체가 들어갑니다.");
     }
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   string a = TimeToString(r[start].time, TIME_DATE), b = TimeToString(r[n - 1].time, TIME_DATE);
   StringReplace(a, ".", "");
   StringReplace(b, ".", "");
   string name = sym + "_M1_" + a + "_" + b + ".csv";
   int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI, ',', CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      Alert("파일을 만들 수 없습니다 (", GetLastError(), ")");
      return;
     }
   FileWriteString(h, "DATE,TIME,OPEN,HIGH,LOW,CLOSE\r\n");
   for(int i = start; i < n; i++)
     {
      FileWriteString(h, TimeToString(r[i].time, TIME_DATE) + "," + TimeToString(r[i].time, TIME_MINUTES) + "," +
                      DoubleToString(r[i].open, dg) + "," + DoubleToString(r[i].high, dg) + "," +
                      DoubleToString(r[i].low, dg) + "," + DoubleToString(r[i].close, dg) + "\r\n");
     }
   FileClose(h);
   string msg = StringFormat("%s 1분봉 %d개 (%s ~ %s) 저장 완료", sym, n - start,
                             TimeToString(r[start].time, TIME_DATE | TIME_MINUTES), TimeToString(r[n - 1].time, TIME_DATE | TIME_MINUTES));
   Print("ExportM1: ", msg);
   Print("ExportM1: 파일 위치 → ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", name);
   if((datetime)r[start].time > from + 3 * 86400)
      Print("ExportM1: 요청한 시작일보다 데이터가 짧습니다. '차트의 최대 바 수'를 늘리거나 1분 차트를 과거로 스크롤해 데이터를 더 받으세요.");
   Alert(msg + "\nMQL5\\Files\\" + name);
  }
//+------------------------------------------------------------------+
