architecture Rtl of AvalonSTToI2S is

  type aInputState is (Waiting, TxLeft, TxRight);

  -- bclk set, for sync and delay
  type aBclkSet is record
    Meta : std_logic;
    Sync : std_logic;
    Dlyd : std_logic;
  end record;

  constant cInitValBclk : aBclkSet := (
    Meta => '0',
    Sync => '0',
    Dlyd => '0'
    );

  type aRegSet is record
    State      : aInputState;           -- current state
    D          : std_logic;             -- serial data
    BitIdx     : unsigned(gDataWidthLen-1 downto 0);  -- current bit index in data
    Bclk       : aBclkSet;              -- bclk signals
    LrcDlyd    : std_logic;             -- left or rigth channel delayed
    LeftData   : std_logic_vector(gDataWidth-1 downto 0);  -- left input data
    LeftValid  : std_logic;             -- left data valid
    RightData  : std_logic_vector(gDataWidth-1 downto 0);  -- right input data
    RightValid : std_logic;             -- right data valid 
  end record;

  constant cInitValR : aRegSet := (
    State      => Waiting,
    D          => '0',
    Bclk       => cInitValBclk,
    LrcDlyd    => '0',
    BitIdx     => (others => '0'),
    LeftData   => (others => '0'),
    LeftValid  => '0',
    RightData  => (others => '0'),
    RightValid => '0'
    );

  signal R, NxR : aRegSet;

begin  -- architecture Rtl

  -- register process
  Reg : process(iClk, inReset)
  begin
    -- low active reset
    if inReset = '0' then
      R <= cInitValR;
    -- rising clk edge
    elsif rising_edge(iClk) then
      R <= NxR;
    end if;
  end process;

  Comb : process (R, iLRC, iBCLK, iLeftValid, iRightValid) is
  begin  -- process

    -- default
    NxR <= R;

    -- read data from bus
    if R.LeftValid = '0' and iLeftValid = '1' then
      NxR.LeftData  <= iLeftData;       -- read data
      NxR.LeftValid <= '1';
    end if;

    if R.RightValid = '0' and iRightValid = '1' then
      NxR.RightData  <= iRightData;     -- read data
      NxR.RightValid <= '1';
    end if;

    -- sync input and delay
    NxR.Bclk.Meta <= iBCLK;
    NxR.Bclk.Sync <= R.Bclk.Meta;
    NxR.Bclk.Dlyd <= R.Bclk.Sync;
    NxR.LrcDlyd   <= iLRC;

    case R.State is

      -- waiting for input data
      when Waiting =>
        -- reset bit index to max index
        NxR.BitIdx <= to_unsigned(gDataWidth, NxR.BitIdx'length);

        -- set output DAT to zero
        NxR.D <= '0';

        if R.LrcDlyd = '0' and iLRC = '1' then
          -- rising edge on LRC - Left Channel
          NxR.State <= TxLeft;

        elsif R.LrcDlyd = '1' and iLRC = '0' then
          -- falling edge on LRC - Right Channel
          NxR.State <= TxRight;
        end if;

      when TxLeft =>
        -- falling edge on BCLK
        if R.Bclk.Dlyd = '1' and R.Bclk.Sync = '0' then

          -- check bit index
          if R.BitIdx = 0 then
            -- end of frame
            NxR.State     <= Waiting;
            NxR.LeftValid <= '0';
          else
            NxR.D      <= R.LeftData(to_integer(R.BitIdx-1));
            -- decrease bit index
            NxR.BitIdx <= R.BitIdx - 1;
          end if;
        end if;


      when TxRight =>
        -- falling edge on BCLK
        if R.Bclk.Dlyd = '1' and R.Bclk.Sync = '0' then

          -- check bit index
          if R.BitIdx = 0 then
            -- end of frame
            NxR.State      <= Waiting;
            NxR.RightValid <= '0';
          else
            NxR.D      <= R.RightData(to_integer(R.BitIdx-1));
            -- decrease bit index
            NxR.BitIdx <= R.BitIdx - 1;
          end if;
        end if;

    end case;

  end process;

  -- output
  oDAT <= R.D;

end architecture Rtl;