//+------------------------------------------------------------------+
//|                                                BinomoBot-1V0.mq4 |
//|                         Copyright 2019-2020, Yaroslav Barabanov. |
//|                                https://t.me/BinaryOptionsScience |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019-2020, Yaroslav Barabanov."
#property link      "https://t.me/BinaryOptionsScience"
#property version   "1.20"
#property strict

#include "binomo_api.mqh"
#include "simple_label.mqh"
#include <WinUser32.mqh>
   int    hwnd=0,MT4InternalMsg=0;
#import "user32.dll"
   int PostMessageW(int hWnd, int Msg, int wParam, int lParam);
	int RegisterWindowMessageW(string lpString); 
#import
#include "xtime.mqh"

input string    aa0  = ">=================================<";   // >==============================<

input string   user_symbols_list = 
         "BTCUSD-BIN,BTCLTC-BIN,ZCRYIDX,EURUSD(OTC)"; // Массив используемых криптовалютных пар 
         
input string   user_symbols_period_list = 
         "1,5";                                       // Массив используемых периодов
                                
static const string pipe_name = "binance_api_bot";    // Имя именнованного канала                   
static const int timer_period = 5;                    // Период таймера (мс)
                     
static datetime last_time = 0;

static string symbol_name[];                 // список символов для обновления графиков
static string symbol_indicator[];            // список символов индикатора
static string symbol_period_str[];           // список периодов (в виде строки)
static uint symbol_period[];                 // список периодов
static uint number_symbol = 0;               // количество символов
static uint number_indicator_symbols = 0;
static uint number_period_symbol = 0;        // количество периодов символов
static MqlRates rates[];
static datetime init_time = 0;
static datetime order_timestamp = 0;
static bool is_open_order = false;           // флаг наличия открытого ордера, нужен для предовтращения повторого открытия того же ордера
static bool is_open_past_order = false;
static bool is_last_connect_status = true;   // последнее состояние соединения

BinomoApi api;   // API для работы с Binance

/** \brief Инициализация бота
 * Данная функция инициализирует все необходимое для запуска бота
 */  
int bot_init();

/** \brief Создать текстову метку
 * Данная функция создает текстовую метку, где отображается баланс и состояние подключения
 */  
bool bot_make_text_label();

int OnInit() {
   return bot_init();
}

void OnTimer() {
   /* место обновление графика */
   api.update_window(symbol_name, symbol_period);
}

void OnDeinit(const int reason) {
   api.close();
   ArrayFree(symbol_name);
   ArrayFree(symbol_indicator);
   ArrayFree(symbol_period_str);
   ArrayFree(rates);
   //LabelDelete(0,"text_broker");
   //LabelDelete(0,"text_status");
   //LabelDelete(0,"text_balance");
   ChartRedraw();
   EventKillTimer();
}

/** \brief Инициализация бота
 * Данная функция инициализирует все необходимое для запуска бота
 */  
int bot_init() {
   /* парсим массив валютных пар */
   string sep=",";
   ushort u_sep;
   u_sep = StringGetCharacter(sep,0);
   int k = StringSplit(user_symbols_list, u_sep, symbol_name);
   number_symbol = ArraySize(symbol_name);
   
   /* парсим массив периодов */
   StringSplit(user_symbols_period_list, u_sep, symbol_period_str);
   number_period_symbol = ArraySize(symbol_period_str);
   ArrayResize(symbol_period, number_period_symbol);
   for(uint p = 0; p < number_period_symbol; ++p) {
      symbol_period[p] = (uint)StringToInteger(symbol_period_str[p]);
   }
   
   /* инициализируем массивы */
   ArraySetAsSeries(rates, true);

   /* запоминаем время инициализации */
   init_time = TimeGMT();

   /* инициализируем обновление графиков */
   api.init_update_window();
   
   /* инициализируем таймер */
   if(!EventSetMillisecondTimer(timer_period)) return(INIT_FAILED);
   return(INIT_SUCCEEDED);
}

/** \brief Создать текстову метку
 * Данная функция создает текстовую метку, где отображается баланс и состояние подключения
 */  
bool bot_make_text_label() {
   const int font_size = 10;
   const int indent = 8;
   long y_distance;
   uint text_broker_width = 140;
   if(!ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0,y_distance)) {
      Print("Failed to get the chart width! Error code = ",GetLastError());
      return false;
   }
   LabelCreate(0,"text_broker",0,indent, (int)y_distance - 2*font_size - 2*indent,CORNER_LEFT_UPPER,"binance status:","Arial",font_size,clrAliceBlue);
   LabelCreate(0,"text_status",0,indent + text_broker_width, (int)y_distance - 2*font_size - 2*indent,CORNER_LEFT_UPPER,"disconnected","Arial",font_size,clrAqua);
   LabelCreate(0,"text_balance",0,indent, (int)y_distance - font_size - indent,CORNER_LEFT_UPPER,"balance: 0","Arial",font_size,clrLightGreen);
   ChartRedraw();
   return true;
}
