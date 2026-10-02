//+------------------------------------------------------------------+
//|                                            TradeDeskExport.mq5   |
//|  Trade Desk 매매일지용 거래내역 자동 내보내기 EA                 |
//|  - 주문을 넣거나 수정하지 않습니다 (읽기 전용)                   |
//|  - 포지션 단위로 묶어서 MQL5\Files\TradeDesk_history.csv 에 저장 |
//+------------------------------------------------------------------+
#property copyright "Trade Desk"
#property version   "1.02"
#property description "Trade Desk 매매일지용 거래내역 자동 내보내기 (읽기 전용, 주문 안 함)"

input int    InpDays     = 0;                       // 내보낼 기간(일), 0 = 전체 (잔고 계산을 위해 전체 권장)
input string InpFileName = "TradeDesk_history.csv"; // 저장 파일 이름 (MQL5\Files)
input int    InpTimerSec = 10;                      // 변경 확인 간격(초)

struct PosRow
  {
   long     id;
   string   sym;
   int      dir;        // 0 = BUY(롱), 1 = SELL(숏)
   double   vin;        // 진입 수량 합계
   double   vout;       // 청산 수량 합계
   double   pin;        // 진입가 x 수량 합계 (가중평균용)
   double   pout;       // 청산가 x 수량 합계
   double   comm;
   double   swap;
   double   fee;
   double   profit;
   double   sl;
   double   tp;
   datetime tin;
   datetime tout;
   long     magic;
   string   comment;
  };

PosRow g_rows[];

// 입출금 (DEAL_TYPE_BALANCE)
ulong    g_cashTicket[];
datetime g_cashTime[];
double   g_cashAmount[];
string   g_cashComment[];
bool   g_dirty = true;

//+------------------------------------------------------------------+
int OnInit()
  {
   EventSetTimer(MathMax(2, InpTimerSec));
   Export();
   // Trade Desk에서 파일을 고를 때 붙여넣을 전체 경로
   Print("TradeDesk: 파일 위치 → ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", InpFileName);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // 체결·포지션 변경(손절/익절 수정 포함)이 생기면 다음 타이머에서 다시 저장
   g_dirty = true;
  }

void OnTimer()
  {
   if(g_dirty)
      Export();
  }

//+------------------------------------------------------------------+
int FindRow(const long id)
  {
   for(int i = ArraySize(g_rows) - 1; i >= 0; i--)
      if(g_rows[i].id == id)
         return(i);
   return(-1);
  }

int AddRow(const long id)
  {
   int n = ArraySize(g_rows);
   ArrayResize(g_rows, n + 1);
   g_rows[n].id      = id;
   g_rows[n].sym     = "";
   g_rows[n].dir     = 0;
   g_rows[n].vin     = 0;
   g_rows[n].vout    = 0;
   g_rows[n].pin     = 0;
   g_rows[n].pout    = 0;
   g_rows[n].comm    = 0;
   g_rows[n].swap    = 0;
   g_rows[n].fee     = 0;
   g_rows[n].profit  = 0;
   g_rows[n].sl      = 0;
   g_rows[n].tp      = 0;
   g_rows[n].tin     = 0;
   g_rows[n].tout    = 0;
   g_rows[n].magic   = 0;
   g_rows[n].comment = "";
   return(n);
  }

// 서버 시간을 PC 현지 시간 문자열(YYYY-MM-DDTHH:MM)로 변환
string LocalTimeStr(const datetime server_time, const int offset)
  {
   if(server_time <= 0)
      return("");
   string s = TimeToString(server_time - offset, TIME_DATE | TIME_MINUTES);
   StringReplace(s, ".", "-");
   StringReplace(s, " ", "T");
   return(s);
  }

string Px(const string sym, const double price)
  {
   if(price <= 0)
      return("");
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;
   return(DoubleToString(price, digits));
  }

string Clean(string s)
  {
   StringReplace(s, ",", " ");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return(s);
  }

//+------------------------------------------------------------------+
void Export()
  {
   datetime from = (InpDays > 0) ? TimeCurrent() - (datetime)InpDays * 86400 : 0;
   if(!HistorySelect(from, TimeCurrent() + 86400))
     {
      Print("TradeDesk: 거래내역을 불러오지 못했습니다");
      return;
     }
   ArrayResize(g_rows, 0);
   ArrayResize(g_cashTicket, 0);
   ArrayResize(g_cashTime, 0);
   ArrayResize(g_cashAmount, 0);
   ArrayResize(g_cashComment, 0);

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(type == DEAL_TYPE_BALANCE)
        {
         // 입금(+) / 출금(-)
         double amt = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(amt != 0)
           {
            int c = ArraySize(g_cashTicket);
            ArrayResize(g_cashTicket, c + 1);
            ArrayResize(g_cashTime, c + 1);
            ArrayResize(g_cashAmount, c + 1);
            ArrayResize(g_cashComment, c + 1);
            g_cashTicket[c]  = ticket;
            g_cashTime[c]    = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            g_cashAmount[c]  = amt;
            g_cashComment[c] = HistoryDealGetString(ticket, DEAL_COMMENT);
           }
         continue;
        }
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue; // 크레딧·보너스 등 제외

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      long   pid   = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      double vol   = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
      datetime t   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      int k = FindRow(pid);
      if(k < 0)
         k = AddRow(pid);

      if(entry == DEAL_ENTRY_IN)
        {
         if(g_rows[k].tin == 0 || t < g_rows[k].tin)
           {
            g_rows[k].tin     = t;
            g_rows[k].sym     = HistoryDealGetString(ticket, DEAL_SYMBOL);
            g_rows[k].dir     = (type == DEAL_TYPE_BUY) ? 0 : 1;
            g_rows[k].magic   = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            g_rows[k].comment = HistoryDealGetString(ticket, DEAL_COMMENT);
           }
         g_rows[k].vin += vol;
         g_rows[k].pin += price * vol;
         if(g_rows[k].sl <= 0)
            g_rows[k].sl = HistoryDealGetDouble(ticket, DEAL_SL);
         if(g_rows[k].tp <= 0)
            g_rows[k].tp = HistoryDealGetDouble(ticket, DEAL_TP);
         // 진입 체결에 손절/익절이 없으면 진입 주문에서 확인
         ulong order = (ulong)HistoryDealGetInteger(ticket, DEAL_ORDER);
         if(order > 0)
           {
            if(g_rows[k].sl <= 0)
               g_rows[k].sl = HistoryOrderGetDouble(order, ORDER_SL);
            if(g_rows[k].tp <= 0)
               g_rows[k].tp = HistoryOrderGetDouble(order, ORDER_TP);
           }
        }
      else // OUT, OUT_BY, INOUT
        {
         g_rows[k].vout += vol;
         g_rows[k].pout += price * vol;
         if(t > g_rows[k].tout)
            g_rows[k].tout = t;
        }

      g_rows[k].comm   += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      g_rows[k].swap   += HistoryDealGetDouble(ticket, DEAL_SWAP);
      g_rows[k].fee    += HistoryDealGetDouble(ticket, DEAL_FEE);
      g_rows[k].profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
     }

   // 아직 열려 있는 포지션: 현재 손절/익절로 보완
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong pt = PositionGetTicket(i);
      if(pt == 0)
         continue;
      long pid = PositionGetInteger(POSITION_IDENTIFIER);
      int k = FindRow(pid);
      if(k < 0)
         continue;
      if(g_rows[k].sl <= 0)
         g_rows[k].sl = PositionGetDouble(POSITION_SL);
      if(g_rows[k].tp <= 0)
         g_rows[k].tp = PositionGetDouble(POSITION_TP);
     }

   // 서버 시간 - PC 시간 차이 (15분 단위로 반올림)
   int offset = (int)(TimeTradeServer() - TimeLocal());
   offset = (int)MathRound(offset / 900.0) * 900;

   string tmp = InpFileName + ".tmp";
   int h = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_ANSI, ',', CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      Print("TradeDesk: 파일을 열 수 없습니다 (", GetLastError(), ")");
      return;
     }
   FileWriteString(h, "position_id,symbol,dir,volume,open_time,open_price,sl,tp,close_time,close_price,commission,swap,fee,profit,net,status,magic,comment,account_currency\r\n");
   string ccy = AccountInfoString(ACCOUNT_CURRENCY);
   int written = 0;

   for(int k = 0; k < ArraySize(g_rows); k++)
     {
      if(g_rows[k].vin <= 0)
         continue; // 진입 체결이 기간 밖인 포지션은 제외
      string status = "OPEN";
      if(g_rows[k].vout >= g_rows[k].vin - 1e-8)
         status = "CLOSED";
      else if(g_rows[k].vout > 0)
         status = "PARTIAL";

      string sym  = g_rows[k].sym;
      double pin  = g_rows[k].pin / g_rows[k].vin;
      double pout = (g_rows[k].vout > 0) ? g_rows[k].pout / g_rows[k].vout : 0;
      double net  = g_rows[k].profit + g_rows[k].comm + g_rows[k].swap + g_rows[k].fee;

      string line =
         IntegerToString(g_rows[k].id) + "," +
         Clean(sym) + "," +
         (g_rows[k].dir == 0 ? "BUY" : "SELL") + "," +
         DoubleToString(g_rows[k].vin, 2) + "," +
         LocalTimeStr(g_rows[k].tin, offset) + "," +
         Px(sym, pin) + "," +
         Px(sym, g_rows[k].sl) + "," +
         Px(sym, g_rows[k].tp) + "," +
         (status == "CLOSED" ? LocalTimeStr(g_rows[k].tout, offset) : "") + "," +
         (status == "CLOSED" ? Px(sym, pout) : "") + "," +
         DoubleToString(g_rows[k].comm, 2) + "," +
         DoubleToString(g_rows[k].swap, 2) + "," +
         DoubleToString(g_rows[k].fee, 2) + "," +
         DoubleToString(g_rows[k].profit, 2) + "," +
         DoubleToString(net, 2) + "," +
         status + "," +
         IntegerToString(g_rows[k].magic) + "," +
         Clean(g_rows[k].comment) + "," +
         ccy + "\r\n";
      FileWriteString(h, line);
      written++;
     }
   // 입출금: status=BALANCE, dir=DEP/WD, net=금액
   for(int c = 0; c < ArraySize(g_cashTicket); c++)
     {
      double amt = g_cashAmount[c];
      string line =
         IntegerToString((long)g_cashTicket[c]) + ",," +
         (amt > 0 ? "DEP" : "WD") + ",," +
         LocalTimeStr(g_cashTime[c], offset) + ",,,,,,,,,," +
         DoubleToString(MathAbs(amt), 2) + ",BALANCE,0," +
         Clean(g_cashComment[c]) + "," +
         ccy + "\r\n";
      FileWriteString(h, line);
     }
   FileClose(h);

   // 다 쓴 뒤 한 번에 교체해서, 읽는 도중 반쯤 쓰인 파일이 보이지 않게 함
   if(!FileMove(tmp, 0, InpFileName, FILE_REWRITE))
     {
      Print("TradeDesk: 파일 교체 실패 (", GetLastError(), ")");
      return;
     }
   g_dirty = false;
   PrintFormat("TradeDesk: %d개 포지션, 입출금 %d건을 %s 에 저장했습니다", written, ArraySize(g_cashTicket), InpFileName);
  }
//+------------------------------------------------------------------+
