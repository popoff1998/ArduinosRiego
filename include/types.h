enum
{
    ENABLED = 0x01,
    REQUESTABLE = 0x02,
    POWERONREAD = 0x04,
};

typedef union
{
    uint8_t all_flags;
    struct
    {
        uint8_t enabled : 1,
            requestable : 1,
            poweronread : 1,
            spare4 : 1,
            spare3 : 1,
            spare2 : 1,
            spare1 : 1,
            spare0 : 1;
    };
} S_FLAGS;

//Estructura de reles
struct sRELE
{
    int id;
    int pin;
    char desc[50];
    bool ON;
    bool OFF;
    int initState;
    int MaxTime;
    unsigned long EndMillis;
    bool enabled;
};

struct sSENSOR
{
    int id;
    int pin;
    int auxPin;
    int MSpresentType;
    int MSmessageType;
    int HWtype;
    int HWsubtype;
    char desc[50];
    MyMessage *msg;
    S_FLAGS flags;
};

struct sCOUNTER
{
    int id;
    int pin;
    char unitDesc[20];
    char desc[50];
    MyMessage *msgVolume;
    MyMessage *msgFlow;
    int mode;
    unsigned long MAXFLOW;
    unsigned long MILLISZEROFLOW;
    unsigned long DEBOUNCEMICROSECS;
    long PULSESFORLITER;
    volatile unsigned long lastBlink;
    volatile unsigned long newBlink;
    double volume;
    double oldVolume;
    volatile double flow;
    double oldFlow;
    unsigned long lastSend;
    unsigned long lastPulse;
    volatile unsigned long pulseCount;
    unsigned long oldPulseCount;
};
