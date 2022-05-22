class PokemonBox
  attr_reader :pokemon
  attr_accessor :name
  attr_accessor :background

  def initialize(name,maxPokemon=30)
    @pokemon=[]
    @name=name
    @background=nil
    for i in 0...maxPokemon
      @pokemon[i]=nil
    end
  end

  def full?
    return (@pokemon.nitems==self.length)
  end

  def nitems
    return @pokemon.nitems
  end

  def length
    return @pokemon.length
  end

  def each
    @pokemon.each{|item| yield item}
  end

  def []=(i,value)
    @pokemon[i]=value
  end

  def [](i)
    return @pokemon[i]
  end
end



class PokemonStorage
  attr_reader :boxes
  attr_reader :party
  attr_accessor :currentBox

  def maxBoxes
    return @boxes.length
  end

  def addBox(n=1) #GM
    for i in 1..n
      @boxes.push(PokemonBox.new(_ISPRINTF("Box " + (maxBoxes+1).to_s), maxPokemon(0)))
    end
  end

  def party
    $Trainer.party
  end

  def party=(value)
    raise ArgumentError.new("Not supported")
  end

  MARKINGCHARS=["●","■","▲","♥"]

  def initialize(maxBoxes=STORAGEBOXES,maxPokemon=16)
    @boxes=[]
    for i in 0...maxBoxes
      ip1=i+1
      @boxes[i]=PokemonBox.new(_ISPRINTF("Box {1:d}",ip1),maxPokemon)
      backid=i%24
      @boxes[i].background="box#{backid}"
    end
    @currentBox=0
    @boxmode=-1
  end

  def maxPokemon(box)
    return 0 if box>=self.maxBoxes
    return box<0 ? 6 : self[box].length
  end

  def [](x,y=nil)
    if y==nil
      return (x==-1) ? self.party : @boxes[x]
    else
      for i in @boxes
        raise "Box is a Pokémon, not a box" if i.is_a?(PokeBattle_Pokemon)
      end
      return (x==-1) ? self.party[y] : @boxes[x][y]
    end
  end

  def []=(x,y,value)
    if x==-1
      self.party[y]=value
    else
      @boxes[x][y]=value
    end
  end

  def full?
    for i in 0...self.maxBoxes
      return false if !@boxes[i].full?
    end
    return true
  end

  def pbFirstFreePos(box)
    if box==-1
      ret=self.party.nitems
      return (ret==6) ? -1 : ret
    else
      for i in 0...maxPokemon(box)
        return i if !self[box,i]
      end
      return -1
    end
  end

  def pbCopy(boxDst,indexDst,boxSrc,indexSrc)
    if indexDst<0 && boxDst<self.maxBoxes
      found=false
      for i in 0...maxPokemon(boxDst)
        if !self[boxDst,i]
          found=true
          indexDst=i
          break
        end
      end
      return false if !found
    end
    if boxDst==-1
      if self.party.nitems>=6
        return false
      end
      self.party[self.party.length]=self[boxSrc,indexSrc]
      self.party.compact!
    else
      if !self[boxSrc,indexSrc]
        raise "Trying to copy nil to storage" # not localized
      end
      self[boxSrc,indexSrc].heal
      self[boxDst,indexDst]=self[boxSrc,indexSrc]
    end
    return true
  end

  def pbMove(boxDst,indexDst,boxSrc,indexSrc)
    return false if !pbCopy(boxDst,indexDst,boxSrc,indexSrc)
    pbDelete(boxSrc,indexSrc)
    return true
  end

  def pbMoveCaughtToParty(pkmn)
    if self.party.nitems>=6
      return false
    end
    self.party[self.party.length]=pkmn
  end

  def pbMoveCaughtToBox(pkmn,box)
    for i in 0...maxPokemon(box)
      if self[box,i]==nil
        pkmn.heal if box>=0
        self[box,i]=pkmn
        return true
      end
    end
    return false
  end

  def pbStoreCaught(pkmn)
    for i in 0...maxPokemon(@currentBox)
      if self[@currentBox,i]==nil
        self[@currentBox,i]=pkmn
        return @currentBox
      end
    end
    for j in 0...self.maxBoxes
      for i in 0...maxPokemon(j)
        if self[j,i]==nil
          self[j,i]=pkmn
          @currentBox=j
          return @currentBox
        end
      end
    end
    return -1
  end

  def pbDelete(box,index)
    if self[box,index]
      self[box,index]=nil
      if box==-1
        self.party.compact!
      end
    end
  end
end



class PokemonStorageWithParty < PokemonStorage
  def party
    return @party
  end

  def party=(value)
    @party=party
  end

  def initialize(maxBoxes=24,maxPokemon=30,party=nil)
    super(maxBoxes,maxPokemon)
    if party
      @party=party
    else
      @party=[]
    end
  end
end



class PokemonStorageScreen
  attr_reader :scene
  attr_reader :storage

  def initialize(scene,storage)
    @scene=scene
    @storage=storage
    @pbHeldPokemon=nil
  end

  def pbConfirm(str)
    return (pbShowCommands(str,[_INTL("Si"),_INTL("No")])==0)
  end

  def pbRelease(selected,heldpoke)
    box=selected[0]
    index=selected[1]
    pokemon=(heldpoke)?heldpoke:@storage[box,index]
    return if !pokemon
    if [PBSpecies::TRISHOUT,PBSpecies::SHULONG,PBSpecies::SHYLEON].include?(pokemon.species)
      pbDisplay(_INTL("You're too attached to this Pokémon to free it."))
      return false
    end
    if pokemon.isEgg?
      pbDisplay(_INTL("You can't release an Egg."))
      return false
    elsif pokemon.mail
      pbDisplay(_INTL("Please remove the mail."))
      return false
    end
    if box==-1 && pbAbleCount<=1 && pbAble?(pokemon) && !heldpoke
      pbDisplay(_INTL("That's your last Pokémon!"))
      return
    end
    command=pbShowCommands(_INTL("Release this Pokémon?"),[_INTL("No"),_INTL("Yes")])
    if command==1
      pkmnname=pokemon.name
      @scene.pbRelease(selected,heldpoke)
      if heldpoke
        @heldpkmn=nil
      else
        @storage.pbDelete(box,index)
      end
      @scene.pbRefresh
      pbDisplay(_INTL("{1} was released.",pkmnname))
      pbDisplay(_INTL("Bye-bye, {1}!",pkmnname))
      @scene.pbRefresh
    end
    return
  end

  def pbMark(selected,heldpoke)
    @scene.pbMark(selected,heldpoke)
  end

  def pbAble?(pokemon)
    pokemon && !pokemon.isEgg? && pokemon.hp>0
  end

  def pbAbleCount
    count=0
    for p in @storage.party
      count+=1 if pbAble?(p)
    end
    return count
  end

  def pbStore(selected,heldpoke)
    box=selected[0]
    index=selected[1]
    if box!=-1
      raise _INTL("Can't deposit from box...")
    end   
    if pbAbleCount<=1 && pbAble?(@storage[box,index]) && !heldpoke
      pbDisplay(_INTL("That's your last Pokémon!"))
    elsif @storage[box,index].mail
      pbDisplay(_INTL("Please remove the Mail."))
    else
      loop do
        destbox=@scene.pbChooseBox(_INTL("Deposit in which Box?"))
        if destbox>=0
          success=false
          firstfree=@storage.pbFirstFreePos(destbox)
          if firstfree<0
            pbDisplay(_INTL("The Box is full."))
            next
          end
          @scene.pbStore(selected,heldpoke,destbox,firstfree)
          if heldpoke
            @storage.pbMoveCaughtToBox(heldpoke,destbox)
            @heldpkmn=nil
          else
            @storage.pbMove(destbox,-1,-1,index)
          end
        end
        break
      end
      @scene.pbRefresh
    end
  end

  def pbWithdraw(selected,heldpoke)
    box=selected[0]
    index=selected[1]
    if box==-1
      raise _INTL("Can't withdraw from party...");
    end
    if @storage.party.nitems>=6
      pbDisplay(_INTL("Your party's full!"))
      return false
    end
    @scene.pbWithdraw(selected,heldpoke,@storage.party.length)
    if heldpoke
      @storage.pbMoveCaughtToParty(heldpoke)
      @heldpkmn=nil
    else
      @storage.pbMove(-1,-1,box,index)
    end
    @scene.pbRefresh
    return true
  end

  def pbDisplay(message)
    @scene.pbDisplay(message)
  end

  def pbSummary(selected,heldpoke)
    @scene.pbSummary(selected,heldpoke)
  end

  def pbHold(selected)
    box=selected[0]
    index=selected[1]
    if box==-1 && pbAble?(@storage[box,index]) && pbAbleCount<=1
      pbDisplay(_INTL("That's your last Pokémon!"))
      return
    end
    @scene.pbHold(selected)
    @heldpkmn=@storage[box,index]
    @storage.pbDelete(box,index) 
    @scene.pbRefresh
  end

  def pbSwap(selected)
    box=selected[0]
    index=selected[1]
    if !@storage[box,index]
      raise _INTL("Position {1},{2} is empty...",box,index)
    end
    if box==-1 && pbAble?(@storage[box,index]) && pbAbleCount<=1 && !pbAble?(@heldpkmn)
      pbDisplay(_INTL("That's your last Pokémon!"))
      return false
    end
    if box!=-1 && @heldpkmn.mail
      pbDisplay("Please remove the mail.")
      return false
    end
    @scene.pbSwap(selected,@heldpkmn)
    @heldpkmn.heal if box>=0
    tmp=@storage[box,index]
    @storage[box,index]=@heldpkmn
    @heldpkmn=tmp
    @scene.pbRefresh
    return true
  end

  def pbPlace(selected)
    box=selected[0]
    index=selected[1]
    if @storage[box,index]
      raise _INTL("Position {1},{2} is not empty...",box,index)
    end
    if box!=-1 && index>=@storage.maxPokemon(box)
      pbDisplay("Can't place that there.")
      return
    end
    if box!=-1 && @heldpkmn.mail
      pbDisplay("Please remove the mail.")
      return
    end
    @heldpkmn.heal if box>=0
    @scene.pbPlace(selected,@heldpkmn)
    @storage[box,index]=@heldpkmn
    if box==-1
      @storage.party.compact!
    end
    @scene.pbRefresh
    @heldpkmn=nil
  end

  def pbItem(selected,heldpoke)
    box=selected[0]
    index=selected[1]
    pokemon=(heldpoke) ? heldpoke : @storage[box,index]
    if pokemon.isEgg?
      pbDisplay(_INTL("Eggs can't hold items."))
      return
    elsif pokemon.mail
      pbDisplay(_INTL("Please remove the mail."))
      return
    end
    if pokemon.item>0
      itemname=PBItems.getName(pokemon.item)
      if pbConfirm(_INTL("Take this {1}?",itemname))
        if !$PokemonBag.pbStoreItem(pokemon.item)
          pbDisplay(_INTL("Can't store the {1}.",itemname))
        else
          pbDisplay(_INTL("Took the {1}.",itemname))
          pokemon.setItem(0)
          @scene.pbHardRefresh
        end
      end
    else
      item=scene.pbChooseItem($PokemonBag)
      if item>0
        itemname=PBItems.getName(item)
        pokemon.setItem(item)
        $PokemonBag.pbDeleteItem(item)
        pbDisplay(_INTL("{1} is now being held.",itemname))
        @scene.pbHardRefresh
      end
    end
  end

  def pbHeldPokemon
    return @heldpkmn
  end

=begin
  commands=[
     _INTL("WITHDRAW POKéMON"),
     _INTL("DEPOSIT POKéMON"),
     _INTL("MOVE POKéMON"),
     _INTL("MOVE ITEMS"),
     _INTL("SEE YA!")
  ]
  helptext=[
     _INTL("Move Pokémon stored in boxes to your party."),
     _INTL("Store Pokémon in your party in Boxes."),
     _INTL("Organize the Pokémon in Boxes and in your party."),
     _INTL("Move items held by any Pokémon in a Box and your party."),
     _INTL("Return to the previous menu."),
  ]
  command=pbShowCommandsAndHelp(commands,helptext)
=end

  def pbShowCommands(msg,commands)
    return @scene.pbShowCommands(msg,commands)
  end

  def pbBoxCommands
    commands=[
       _INTL("Jump"),
       _INTL("Wallpaper"),
       _INTL("Name"),
       _INTL("Cancel"),
    ]
    command=pbShowCommands(
       _INTL("What do you want to do?"),commands)
    case command
    when 0
      destbox=@scene.pbChooseBox(_INTL("Jump to which Box?"))
      if destbox>=0
        @scene.pbJumpToBox(destbox)
      end
    when 1
      commands=[
         _INTL("Forest"),
         _INTL("City"),
         _INTL("Desert"),
         _INTL("Savanna"),
         _INTL("Crag"),
         _INTL("Volcano"),
         _INTL("Snow"),
         _INTL("Cave"),
         _INTL("Beach"),
         _INTL("Seafloor"),
         _INTL("River"),
         _INTL("Sky"),
         _INTL("Poké Center"),
         _INTL("Machine"),
         _INTL("Checks"),
         _INTL("Simple"),
         _INTL("Heart"),
         _INTL("Soul"),
         _INTL("Retro"),
         _INTL("Compete"),
         _INTL("Trio"),
         _INTL("Pika"),
         _INTL("Kimono Girl"),
         _INTL("Rocket")
      ]
      wpaper=pbShowCommands(_INTL("Pick the wallpaper."),commands)
      if wpaper>=0
        @scene.pbChangeBackground(wpaper)
      end
    when 2
      @scene.pbBoxName(_INTL("Box name?"),0,12)
    end
  end

  def pbChoosePokemon(party=nil)
    @heldpkmn=nil
    @scene.pbStartBox(self,2)
    retval=nil
    loop do
      selected=@scene.pbSelectBox(@storage.party)
      if selected && selected[0]==-3 # Close box
        if pbConfirm(_INTL("Exit from the Box?"))
          break
        else
          next
        end
      end
      if selected==nil
        if pbConfirm(_INTL("Continue Box operations?"))
          next
        else
          break
        end
      elsif selected[0]==-4 # Box name
        pbBoxCommands
      else
        pokemon=@storage[selected[0],selected[1]]
        next if !pokemon
        commands=[
           _INTL("Select"),
           _INTL("Summary"),
           _INTL("Withdraw"),
           _INTL("Item"),
           _INTL("Mark")
        ]
        commands.push(_INTL("Cancel"))
        commands[2]=_INTL("Store") if selected[0]==-1
        helptext=_INTL("{1} is selected.",pokemon.name)
        command=pbShowCommands(helptext,commands)
        case command
        when 0 # Move/Shift/Place
          if pokemon
            retval=selected
            break
          end
        when 1 # Summary
          pbSummary(selected,nil)
        when 2 # Withdraw
          if selected[0]==-1
            pbStore(selected,nil)
          else
            pbWithdraw(selected,nil)
          end
        when 3 # Item
          pbItem(selected,nil)
        when 4 # Mark
          pbMark(selected,nil)
        end
      end
    end
    @scene.pbCloseBox
    return retval
  end

  def pbStartScreen(command)
    @heldpkmn=nil
    if command==0
### WITHDRAW ###################################################################
      @scene.pbStartBox(self,command)
      loop do
        selected=@scene.pbSelectBox(@storage.party)
        if selected && selected[0]==-3 # Close box
          if pbConfirm(_INTL("Exit from the Box?"))
            break
          else
            next
          end
        end
        if selected && selected[0]==-2 # Party Pokémon
          pbDisplay(_INTL("Which one will you take?"))
          next
        end
        if selected && selected[0]==-4 # Box name
          pbBoxCommands
          next
        end
        if selected==nil
          if pbConfirm(_INTL("Continue Box operations?"))
            next
          else
            break
          end
        else
          pokemon=@storage[selected[0],selected[1]]
          next if !pokemon
          command=pbShowCommands(
             _INTL("{1} is selected.",pokemon.name),[_INTL("Withdraw"),
             _INTL("Summary"),_INTL("Mark"),_INTL("Release"),_INTL("Cancel")])
          case command
          when 0 # Withdraw
            pbWithdraw(selected,nil)
          when 1 # Summary
            pbSummary(selected,nil)
          when 2 # Mark
            pbMark(selected,nil)
          when 3 # Release
            pbRelease(selected,nil)
          end
        end
      end
      @scene.pbCloseBox
    elsif command==1
### DEPOSIT ####################################################################
      @scene.pbStartBox(self,command)
      loop do
        selected=@scene.pbSelectParty(@storage.party)
        if selected==-3 # Close box
          if pbConfirm(_INTL("Exit from the Box?"))
            break
          else
            next
          end
        end
        if selected<0
          if pbConfirm(_INTL("Continue Box operations?"))
            next
          else
            break
          end
        else
          pokemon=@storage[-1,selected]
          next if !pokemon
          command=pbShowCommands(
             _INTL("{1} is selected.",pokemon.name),[_INTL("Store"),
             _INTL("Summary"),_INTL("Mark"),_INTL("Release"),_INTL("Cancel")])
          case command
          when 0 # Store
            pbStore([-1,selected],nil)
          when 1 # Summary
            pbSummary([-1,selected],nil)
          when 2 # Mark
            pbMark([-1,selected],nil)
          when 3 # Release
            pbRelease([-1,selected],nil)
          end
        end
      end
      @scene.pbCloseBox
    elsif command==2
### MOVE #######################################################################
      @scene.pbStartBox(self,command)
      loop do
        selected=@scene.pbSelectBox(@storage.party)
        if selected && selected[0]==-3 # Close box
          if pbHeldPokemon
            pbDisplay(_INTL("You're holding a Pokémon!"))
            next
          end
          if pbConfirm(_INTL("Exit from the Box?"))
            break
          else
            next
          end
        end
        if selected==nil
          if pbHeldPokemon
            pbDisplay(_INTL("You're holding a Pokémon!"))
            next
          end
          if pbConfirm(_INTL("Continue Box operations?"))
            next
          else
            break
          end
        elsif selected[0]==-4 # Box name
          pbBoxCommands
        else
          pokemon=@storage[selected[0],selected[1]]
          commands=[
             _INTL("Move"),
             _INTL("Summary"),
             _INTL("Withdraw"),
             _INTL("Item"),
             _INTL("Mark"),
             _INTL("Release")
          ]
          commands.push(_INTL("Debug")) if $DEBUG
          commands.push(_INTL("Cancel"))
          heldpoke=pbHeldPokemon
          if heldpoke
            helptext=_INTL("{1} is selected.",heldpoke.name)
            commands[0]=pokemon ? _INTL("Shift") : _INTL("Place")
          elsif pokemon
            helptext=_INTL("{1} is selected.",pokemon.name)
            commands[0]=_INTL("Move")
          else
            next
          end
          if selected[0]==-1
            commands[2]=_INTL("Store")
          else
            commands[2]=_INTL("Withdraw")
          end
          command=pbShowCommands(helptext,commands)
          case command
          when 0 # Move/Shift/Place
            if @heldpkmn && pokemon
              pbSwap(selected)
            elsif @heldpkmn
              pbPlace(selected)
            else
              pbHold(selected)
            end
          when 1 # Summary
            pbSummary(selected,@heldpkmn)
          when 2 # Withdraw
            if selected[0]==-1
              pbStore(selected,@heldpkmn)
            else
              pbWithdraw(selected,@heldpkmn)
            end
          when 3 # Item
            pbItem(selected,@heldpkmn)
          when 4 # Mark
            pbMark(selected,@heldpkmn)
          when 5 # Release
            pbRelease(selected,@heldpkmn)
          when 6
            if $DEBUG
              pkmn=@heldpkmn ? @heldpkmn : pokemon
              debugMenu(selected,pkmn,heldpoke)
            end
          end
        end
      end
      @scene.pbCloseBox
    elsif command==3
      @scene.pbStartBox(self,command)
      @scene.pbCloseBox
    end
  end

  def debugMenu(selected,pkmn,heldpoke)
    command=0
  end

  def selectPokemon(index)
    pokemon=@storage[@currentbox,index]
    if !pokemon
      return nil
    end
  end
end



class Interpolator
  ZOOM_X  = 1
  ZOOM_Y  = 2
  X       = 3
  Y       = 4
  OPACITY = 5
  COLOR   = 6
  WAIT    = 7

  def initialize
    @tweening=false
    @tweensteps=[]
    @sprite=nil
    @frames=0
    @step=0
  end

  def tweening?
    return @tweening
  end

  def tween(sprite,items,frames)
    @tweensteps=[]
    if sprite && !sprite.disposed? && frames>0
      @frames=frames
      @step=0
      @sprite=sprite
      for item in items
        case item[0]
        when ZOOM_X
          @tweensteps[item[0]]=[sprite.zoom_x,item[1]-sprite.zoom_x]
        when ZOOM_Y
          @tweensteps[item[0]]=[sprite.zoom_y,item[1]-sprite.zoom_y]
        when X
          @tweensteps[item[0]]=[sprite.x,item[1]-sprite.x]
        when Y
          @tweensteps[item[0]]=[sprite.y,item[1]-sprite.y]
        when OPACITY
          @tweensteps[item[0]]=[sprite.opacity,item[1]-sprite.opacity]
        when COLOR
          @tweensteps[item[0]]=[sprite.color.clone,Color.new(
             item[1].red-sprite.color.red,
             item[1].green-sprite.color.green,
             item[1].blue-sprite.color.blue,
             item[1].alpha-sprite.color.alpha
          )]
        end
      end
      @tweening=true
    end
  end

  def update
    if @tweening
      t=(@step*1.0)/@frames
      for i in 0...@tweensteps.length
        item=@tweensteps[i]
        next if !item
        case i
        when ZOOM_X
          @sprite.zoom_x=item[0]+item[1]*t
        when ZOOM_Y
          @sprite.zoom_y=item[0]+item[1]*t
        when X
          @sprite.x=item[0]+item[1]*t
        when Y
          @sprite.y=item[0]+item[1]*t
        when OPACITY
          @sprite.opacity=item[0]+item[1]*t
        when COLOR
          @sprite.color=Color.new(
             item[0].red+item[1].red*t,
             item[0].green+item[1].green*t,
             item[0].blue+item[1].blue*t,
             item[0].alpha+item[1].alpha*t
          )
        end
      end
      @step+=1
      if @step==@frames
        @step=0
        @frames=0
        @tweening=false
      end
    end
  end
end



class PokemonBoxIcon < IconSprite
  def initialize(pokemon,viewport=nil)
    super(0,0,viewport)
    @release=Interpolator.new
    @startRelease=false
    @pokemon=pokemon
    if pokemon
      self.setBitmap(pbPokemonIconFile(pokemon))
    end
    self.src_rect=Rect.new(0,0,64,64)
  end

  def release
    self.ox=32
    self.oy=32
    self.x+=32
    self.y+=32
    @release.tween(self,[
       [Interpolator::ZOOM_X,0],
       [Interpolator::ZOOM_Y,0],
       [Interpolator::OPACITY,0]
    ],100)
    @startRelease=true
  end

  def releasing?
    return @release.tweening?
  end

  def update
    super
    @release.update
    self.color=Color.new(0,0,0,0)
    dispose if @startRelease && !releasing?
  end
end



class PokemonBoxArrow < SpriteWrapper
  def initialize(viewport=nil)
    super(viewport)
    @frame=0
    @holding=false
    @updating=false
    @grabbingState=0
    @placingState=0
    @heldpkmn=nil
    @swapsprite=nil
    @fist=AnimatedBitmap.new("Graphics/Pictures/boxfist")
    @point1=AnimatedBitmap.new("Graphics/Pictures/boxpoint1")
    @point2=AnimatedBitmap.new("Graphics/Pictures/boxpoint2")
    @grab=AnimatedBitmap.new("Graphics/Pictures/boxgrab")
    @currentBitmap=@fist
    @spriteX=self.x
    @spriteY=self.y
    self.bitmap=@currentBitmap.bitmap
  end

  def heldPokemon
    @heldpkmn=nil if @heldpkmn && @heldpkmn.disposed?
    @holding=false if !@heldpkmn
    return @heldpkmn
  end

  def visible=(value)
    super
    sprite=heldPokemon
    sprite.visible=value if sprite
  end

  def color=(value)
    super
    sprite=heldPokemon
    sprite.color=value if sprite
  end

  def dispose
    @fist.dispose
    @point1.dispose
    @point2.dispose
    @grab.dispose
    @heldpkmn.dispose if @heldpkmn
    super
  end

  def holding?
    return self.heldPokemon && @holding
  end

  def grabbing?
    return @grabbingState>0
  end

  def placing?
    return @placingState>0
  end

  def x=(value)
    super
    @spriteX=x if !@updating
    heldPokemon.x=self.x if holding?
  end

  def y=(value)
    super
    @spriteY=y if !@updating
    heldPokemon.y=self.y+16 if holding?
  end

  def setSprite(sprite)
    if holding?
      @heldpkmn=sprite
      @heldpkmn.viewport=self.viewport if @heldpkmn
      @heldpkmn.z=1 if @heldpkmn
      @holding=false if !@heldpkmn
      self.z=2
    end
  end

  def deleteSprite
    @holding=false
    if @heldpkmn
      @heldpkmn.dispose
      @heldpkmn=nil
    end
  end

  def grab(sprite)
    @grabbingState=1
    @heldpkmn=sprite
    @heldpkmn.viewport=self.viewport
    @heldpkmn.z=1
    self.z=2
  end

  def place
    @placingState=1
  end

  def release
    if @heldpkmn
      @heldpkmn.release
    end
  end

  def update
    @updating=true
    super
    heldpkmn=heldPokemon
    heldpkmn.update if heldpkmn
    @fist.update
    @point2.update
    @point1.update
    @grab.update
    self.bitmap=@currentBitmap.bitmap
    @holding=false if !heldpkmn
    if @grabbingState>0
      if @grabbingState<=8
        @currentBitmap=@grab
        self.bitmap=@currentBitmap.bitmap
        self.y=@spriteY+(@grabbingState)*2
        @grabbingState+=1
      elsif @grabbingState<=16
        @holding=true
        @currentBitmap=@fist
        self.bitmap=@currentBitmap.bitmap
        self.y=@spriteY+(16-@grabbingState)*2
        @grabbingState+=1
      else
        @grabbingState=0
      end
    elsif @placingState>0
      if @placingState<=8
        @currentBitmap=@fist
        self.bitmap=@currentBitmap.bitmap
        self.y=@spriteY+(@placingState)*2
        @placingState+=1
      elsif @placingState<=16
        @holding=false
        @heldpkmn=nil
        @currentBitmap=@grab
        self.bitmap=@currentBitmap.bitmap
        self.y=@spriteY+(16-@placingState)*2
        @placingState+=1
      else
        @placingState=0
      end
    elsif holding?
      @currentBitmap=@fist
      self.bitmap=@currentBitmap.bitmap
    else
      self.x=@spriteX
      self.y=@spriteY
      if (@frame/20)==1
        @currentBitmap=@point2
        self.bitmap=@currentBitmap.bitmap
      else
        @currentBitmap=@point1
        self.bitmap=@currentBitmap.bitmap
      end
    end
    @frame+=1
    @frame=0 if @frame==40
    @updating=false
  end
end



class PokemonBoxPartySprite < SpriteWrapper
  def deletePokemon(index)
    @pokemonsprites[index].dispose
    @pokemonsprites[index]=nil
    @pokemonsprites.compact!
    refresh
  end

  def getPokemon(index)
    return @pokemonsprites[index]
  end

  def setPokemon(index,sprite)
    @pokemonsprites[index]=sprite
    @pokemonsprites.compact!
    refresh
  end

  def grabPokemon(index,arrow)
    sprite=@pokemonsprites[index]
    if sprite
      arrow.grab(sprite)
      @pokemonsprites[index]=nil
      @pokemonsprites.compact!
      refresh
    end
  end

  def x=(value)
    super
    refresh
  end

  def y=(value)
    super
    refresh
  end

  def color=(value)
    super
    for i in 0...6
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].color=pbSrcOver(@pokemonsprites[i].color,value)
      end
    end
    refresh
  end

  def visible=(value)
    super
    for i in 0...6
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].visible=value
      end
    end
    refresh
  end

  def initialize(party,viewport=nil)
    super(viewport)
    @boxbitmap=AnimatedBitmap.new("Graphics/Pictures/boxpartytab")
    @pokemonsprites=[]
    @party=party
    for i in 0...6
      @pokemonsprites[i]=nil
      pokemon=@party[i]
      if pokemon
        @pokemonsprites[i]=PokemonBoxIcon.new(pokemon,viewport)
      end
    end
    @contents=BitmapWrapper.new(172,352)
    self.bitmap=@contents
    self.x=182
    self.y=Graphics.height-352
    refresh
  end

  def dispose
    for i in 0...6
      @pokemonsprites[i].dispose if @pokemonsprites[i]
    end
    @contents.dispose
    @boxbitmap.dispose
    super
  end

  def refresh
    @contents.blt(0,0,@boxbitmap.bitmap,Rect.new(0,0,172,352))
    xvalues=[16,92,16,92,16,92]
    yvalues=[0,16,64,80,128,144]
    for j in 0...6
      @pokemonsprites[j]=nil if @pokemonsprites[j] && @pokemonsprites[j].disposed?
    end
    @pokemonsprites.compact!
    for j in 0...6
      sprite=@pokemonsprites[j]
      if sprite && !sprite.disposed?
        sprite.viewport=self.viewport
        sprite.z=0
        sprite.x=self.x+xvalues[j]
        sprite.y=self.y+yvalues[j]
      end
    end
  end

  def update
    super
    for i in 0...6
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].update
      end
    end
  end
end



class MosaicPokemonSprite < PokemonSprite
  def initialize(*args)
    super(*args)
    @mosaic=0
    @inrefresh=false
    @mosaicbitmap=nil
    @mosaicbitmap2=nil
    @oldbitmap=self.bitmap
  end

  attr_reader :mosaic

  def mosaic=(value)
    @mosaic=value
    @mosaic=0 if @mosaic<0
    mosaicRefresh(@oldbitmap)
  end

  def dispose
    super
    @mosaicbitmap.dispose if @mosaicbitmap
    @mosaicbitmap=nil
    @mosaicbitmap2.dispose if @mosaicbitmap2
    @mosaicbitmap2=nil
  end

  def bitmap=(value)
    super
    mosaicRefresh(value)
  end

  def mosaicRefresh(bitmap)
    return if @inrefresh
    @inrefresh=true
    @oldbitmap=bitmap
    if @mosaic<=0 || !@oldbitmap
      @mosaicbitmap.dispose if @mosaicbitmap
      @mosaicbitmap=nil
      @mosaicbitmap2.dispose if @mosaicbitmap2
      @mosaicbitmap2=nil
      self.bitmap=@oldbitmap
    else
      newWidth=[(@oldbitmap.width/@mosaic),1].max
      newHeight=[(@oldbitmap.height/@mosaic),1].max
      @mosaicbitmap2.dispose if @mosaicbitmap2
      @mosaicbitmap=pbDoEnsureBitmap(@mosaicbitmap,newWidth,newHeight)
      @mosaicbitmap.clear
      @mosaicbitmap2=pbDoEnsureBitmap(@mosaicbitmap2,
         @oldbitmap.width,@oldbitmap.height)
      @mosaicbitmap2.clear
      @mosaicbitmap.stretch_blt(Rect.new(0,0,newWidth,newHeight),
         @oldbitmap,@oldbitmap.rect)
      @mosaicbitmap2.stretch_blt(
         Rect.new(-@mosaic/2+1,-@mosaic/2+1,
         @mosaicbitmap2.width,@mosaicbitmap2.height),
         @mosaicbitmap,Rect.new(0,0,newWidth,newHeight))
      self.bitmap=@mosaicbitmap2
    end
    @inrefresh=false
  end
end



class AutoMosaicPokemonSprite < MosaicPokemonSprite
  def update
    super
    self.mosaic-=1
  end
end



class PokemonBoxSprite < SpriteWrapper
  attr_accessor :refreshBox
  attr_accessor :refreshSprites
  def deletePokemon(index)
    @pokemonsprites[index].dispose
    @pokemonsprites[index]=nil
    refresh
  end

  def getPokemon(index)
    return @pokemonsprites[index]
  end

  def setPokemon(index,sprite)
    @pokemonsprites[index]=sprite
    refresh
  end

  def grabPokemon(index,arrow)
    sprite=@pokemonsprites[index]
    if sprite
      arrow.grab(sprite)
      @pokemonsprites[index]=nil
      refresh
    end
  end

  def x=(value)
    super
    refresh
  end

  def y=(value)
    super
    refresh
  end

  def color=(value)
    super
    if @refreshSprites
      for i in 0...30
        if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
          @pokemonsprites[i].color=value
        end
      end
    end
    refresh
  end

  def visible=(value)
    super
    for i in 0...30
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].visible=value
      end
    end
    refresh
  end

  def getBoxBitmap
    if !@bg || @bg!=@storage[@boxnumber].background
      curbg=@storage[@boxnumber].background
      if !curbg || curbg.length==0
        boxid=@boxnumber%24
        @bg="box#{boxid}"
      else
        @bg="#{curbg}"
      end
      @boxbitmap.dispose if @boxbitmap
      @boxbitmap=AnimatedBitmap.new("Graphics/Pictures/#{@bg}")
    end
  end

  def initialize(storage,boxnumber,viewport=nil)
    super(viewport)
    @storage=storage
    @boxnumber=boxnumber
    @refreshBox=true
    @refreshSprites=true
    @bg=nil
    @boxbitmap=nil
    getBoxBitmap
    @pokemonsprites=[]
    for i in 0...30
      @pokemonsprites[i]=nil
      pokemon=@storage[boxnumber,i]
      if pokemon
        @pokemonsprites[i]=PokemonBoxIcon.new(pokemon,viewport)
      else
        @pokemonsprites[i]=PokemonBoxIcon.new(nil,viewport)
      end
    end
    @contents=BitmapWrapper.new(324,296)
    self.bitmap=@contents
    self.x=184
    self.y=18
    refresh
  end

  def dispose
    if !disposed?
      for i in 0...30
        @pokemonsprites[i].dispose if @pokemonsprites[i]
        @pokemonsprites[i]=nil
      end
      @contents.dispose
      @boxbitmap.dispose
      super
    end
  end

  def refresh
    if @refreshBox
      boxname=@storage[@boxnumber].name
      getBoxBitmap
      @contents.blt(0,0,@boxbitmap.bitmap,Rect.new(0,0,324,296))
      pbSetSystemFont(@contents)
      widthval=@contents.text_size(boxname).width
      xval=162-(widthval/2)
      pbDrawShadowText(@contents,xval,8,widthval,32,boxname,
         Color.new(248,248,248),Color.new(40,48,48))
      @refreshBox=false
    end
    yval=self.y+30
    for j in 0...5
      xval=self.x+10
      for k in 0...6
        sprite=@pokemonsprites[j*6+k]
        if sprite && !sprite.disposed?
          sprite.viewport=self.viewport
          sprite.z=0
          sprite.x=xval
          sprite.y=yval
        end
        xval+=48
      end
      yval+=48
    end
  end

  def update
    super
    for i in 0...30
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].update
      end
    end
  end
end



class PokemonStorageScene
  def initialize
    @command=0
  end

  def pbStartBox(screen,command)
    @screen=screen
    @storage=screen.storage
    @bgviewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @bgviewport.z=99999
    @boxviewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @boxviewport.z=99999
    @boxsidesviewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @boxsidesviewport.z=99999
    @arrowviewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @arrowviewport.z=99999
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=99999
    @selection=0
    @sprites={}
    @choseFromParty=false
    @command=command
    addBackgroundPlane(@sprites,"background","boxbg",@bgviewport)
    @sprites["box"]=PokemonBoxSprite.new(@storage,@storage.currentBox,@boxviewport)
    @sprites["boxsides"]=IconSprite.new(0,0,@boxsidesviewport)
    @sprites["boxsides"].setBitmap("Graphics/Pictures/boxsides")
    @sprites["overlay"]=BitmapSprite.new(Graphics.width,Graphics.height,@boxsidesviewport)
    @sprites["pokemon"]=AutoMosaicPokemonSprite.new(@boxsidesviewport)
    pbSetSystemFont(@sprites["overlay"].bitmap)
    @sprites["boxparty"]=PokemonBoxPartySprite.new(@storage.party,@boxsidesviewport)
    if command!=1 # Drop down tab only on Deposit
      @sprites["boxparty"].x=182
      @sprites["boxparty"].y=Graphics.height
    end
    @sprites["arrow"]=PokemonBoxArrow.new(@arrowviewport)
    @sprites["arrow"].z+=1
    if command!=1
      pbSetArrow(@sprites["arrow"],@selection)
      pbUpdateOverlay(@selection)
      pbSetMosaic(@selection)
    else
      pbPartySetArrow(@sprites["arrow"],@selection)
      pbUpdateOverlay(@selection,@storage.party)
      pbSetMosaic(@selection)
    end
    pbFadeInAndShow(@sprites)
  end

  def pbCloseBox
    pbFadeOutAndHide(@sprites)  
    pbDisposeSpriteHash(@sprites)
    @boxviewport.dispose
    @boxsidesviewport.dispose
    @arrowviewport.dispose
  end

  def pbSetArrow(arrow,selection)
    case selection
    when -1, -4, -5 # Box name, move left, move right
      arrow.y=-16
      arrow.x=157*2
    when -2 # Party Pokémon
      arrow.y=143*2
      arrow.x=119*2
    when -3 # Close Box
      arrow.y=143*2
      arrow.x=207*2
    else
      arrow.x = (97+24*(selection%6) ) * 2
      arrow.y = (8+24*(selection/6) ) * 2
    end
  end

  def pbChangeSelection(key,selection)
    case key
    when Input::UP
      if selection==-1 # Box name
        selection=-2
      elsif selection==-2 # Party
        selection=25
      elsif selection==-3 # Close Box
        selection=28
      else
        selection-=6
        selection=-1 if selection<0
      end
    when Input::DOWN
      if selection==-1 # Box name
        selection=2
      elsif selection==-2 # Party
        selection=-1
      elsif selection==-3 # Close Box
        selection=-1
      else
        selection+=6
        selection=-2 if selection==30||selection==31||selection==32
        selection=-3 if selection==33||selection==34||selection==35
      end
    when Input::RIGHT
      if selection==-1 # Box name
        selection=-5 # Move to next box
      elsif selection==-2
        selection=-3
      elsif selection==-3
        selection=-2
      else
        selection+=1
        selection-=6 if selection%6==0
      end
    when Input::LEFT
      if selection==-1 # Box name
        selection=-4 # Move to previous box
      elsif selection==-2
        selection=-3
      elsif selection==-3
        selection=-2
      else
        selection-=1
        selection+=6 if selection==-1||selection%6==5
      end
    end
    return selection
  end

  def pbPartySetArrow(arrow,selection)
    if selection>=0
      xvalues=[99,137,99,137,99,137,118]
      yvalues=[0,8,32,40,64,72,114]
      arrow.angle=0
      arrow.mirror=false
      arrow.ox=0
      arrow.oy=0
      arrow.x=xvalues[selection]*2
      arrow.y=yvalues[selection]*2
    end
  end

  def pbPartyChangeSelection(key,selection)
    case key
    when Input::LEFT
      selection-=1
      selection=6 if selection<0
    when Input::RIGHT
      selection+=1
      selection=0 if selection>6
    when Input::UP
      if selection==6
        selection=5
      else
        selection-=2
        selection=6 if selection<0
      end
    when Input::DOWN
      if selection==6
        selection=0
      else
        selection+=2
        selection=6 if selection>6
      end
    end
    return selection
  end

  def pbSelectPartyInternal(party,depositing)
    selection=@selection
    pbPartySetArrow(@sprites["arrow"],selection)
    pbUpdateOverlay(selection,party)
    pbSetMosaic(selection)
    lastsel=1
    loop do
      Graphics.update
      Input.update
      key=-1
      key=Input::DOWN if Input.repeat?(Input::DOWN)
      key=Input::RIGHT if Input.repeat?(Input::RIGHT)
      key=Input::LEFT if Input.repeat?(Input::LEFT)
      key=Input::UP if Input.repeat?(Input::UP)
      if key>=0
        pbPlayCursorSE()
        newselection=pbPartyChangeSelection(key,selection)
        if newselection==-1
          return -1 if !depositing
        elsif newselection==-2
          selection=lastsel
        else
          selection=newselection
        end
        pbPartySetArrow(@sprites["arrow"],selection)
        lastsel=selection if selection>0
        pbUpdateOverlay(selection,party)
        pbSetMosaic(selection)
      end
      pbUpdateSpriteHash(@sprites)
      if Input.trigger?(Input::C)
        if selection>=0 && selection<6
          @selection=selection
          return selection
        elsif selection==6 # Close Box 
          @selection=selection
          return (depositing) ? -3 : -1
        end
      end
      if Input.trigger?(Input::B)
        @selection=selection
        return -1
      end
    end
  end

  def pbSelectParty(party)
    return pbSelectPartyInternal(party,true)
  end

  def pbChangeBackground(wp)
    @sprites["box"].refreshSprites=false
    alpha=0
    Graphics.update
    pbUpdateSpriteHash(@sprites)
    16.times do
      alpha+=16
      Graphics.update
      Input.update
      @sprites["box"].color=Color.new(248,248,248,alpha)
      pbUpdateSpriteHash(@sprites)
    end
    @sprites["box"].refreshBox=true
    @storage[@storage.currentBox].background="box#{wp}"
    4.times do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
    end
    16.times do
      alpha-=16
      Graphics.update
      Input.update
      @sprites["box"].color=Color.new(248,248,248,alpha)
      pbUpdateSpriteHash(@sprites)
    end
    @sprites["box"].refreshSprites=true
  end

  def pbSwitchBoxToRight(newbox)
    newbox=PokemonBoxSprite.new(@storage,newbox,@boxviewport)
    newbox.x=520
    Graphics.frame_reset
    begin
      Graphics.update
      Input.update
      @sprites["box"].x-=32
      newbox.x-=32
      pbUpdateSpriteHash(@sprites)
    end until newbox.x<=184
    diff=newbox.x-184
    newbox.x=184; @sprites["box"].x-=diff
    @sprites["box"].dispose
    @sprites["box"]=newbox
  end

  def pbSwitchBoxToLeft(newbox)
    newbox=PokemonBoxSprite.new(@storage,newbox,@boxviewport)
    newbox.x=-152
    Graphics.frame_reset
    begin
      Graphics.update
      Input.update
      @sprites["box"].x+=32
      newbox.x+=32
      pbUpdateSpriteHash(@sprites)
    end until newbox.x>=184
    diff=newbox.x-184
    newbox.x=184; @sprites["box"].x-=diff
    @sprites["box"].dispose
    @sprites["box"]=newbox
  end

  def pbJumpToBox(newbox)
    if @storage.currentBox!=newbox
      if newbox>@storage.currentBox
        pbSwitchBoxToRight(newbox)
      else
        pbSwitchBoxToLeft(newbox)
      end
      @storage.currentBox=newbox
    end
  end

  def pbBoxName(helptext,minchars,maxchars)
    oldsprites=pbFadeOutAndHide(@sprites)
    ret=pbEnterBoxName(helptext,minchars,maxchars)
    if ret.length>0
      @storage[@storage.currentBox].name=ret
    end
    @sprites["box"].refreshBox=true
    pbRefresh
    pbFadeInAndShow(@sprites,oldsprites)
  end

  def pbUpdateOverlay(selection,party=nil)
    overlay=@sprites["overlay"].bitmap
    overlay.clear
    pokemon=nil
    if @screen.pbHeldPokemon
      pokemon=@screen.pbHeldPokemon
    elsif selection>=0
      pokemon=(party) ? party[selection] : @storage[@storage.currentBox,selection]
    end
    if !pokemon
      @sprites["pokemon"].visible=false
      return
    end
    @sprites["pokemon"].visible=true
    speciesname=PBSpecies.getName(pokemon.species)
    itemname="No item"
    if pokemon.item>0
      itemname=PBItems.getName(pokemon.item)
    end
    abilityname="No ability"
    if pokemon.ability>0
      abilityname=PBAbilities.getName(pokemon.ability)
    end
    base=Color.new(88,88,80)
    shadow=Color.new(168,184,184)
    pokename=pokemon.name
    textstrings=[
       [pokename,10,8,false,base,shadow]
    ]
    if !pokemon.isEgg?
      if pokemon.isMale?
        textstrings.push([_INTL("♂"),148,8,false,Color.new(24,112,216),Color.new(136,168,208)])
      elsif pokemon.isFemale?
        textstrings.push([_INTL("♀"),148,8,false,Color.new(248,56,32),Color.new(224,152,144)])
      end
      textstrings.push([_INTL("{1}",pokemon.level),36,234,false,base,shadow])
      textstrings.push([_INTL("{1}",abilityname),85,306,2,base,shadow])
      textstrings.push([_INTL("{1}",itemname),85,342,2,base,shadow])
    end
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay,textstrings)
    textstrings.clear
    if !pokemon.isEgg?
      textstrings.push([_INTL("Lv."),10,238,false,base,shadow])
    end
    pbSetSmallFont(overlay)
    pbDrawTextPositions(overlay,textstrings)
    if pokemon.isShiny?
      imagepos=[(["Graphics/Pictures/shiny",156,198,0,0,-1,-1])]
      pbDrawImagePositions(overlay,imagepos)
    end
    typebitmap=AnimatedBitmap.new(_INTL("Graphics/Pictures/types"))
    type1rect=Rect.new(0,pokemon.type1*28,64,28)
    type2rect=Rect.new(0,pokemon.type2*28,64,28)
    if pokemon.type1==pokemon.type2
      overlay.blt(52,272,typebitmap.bitmap,type1rect)
    else
      overlay.blt(18,272,typebitmap.bitmap,type1rect)
      overlay.blt(88,272,typebitmap.bitmap,type2rect)
    end
    drawMarkings(overlay,66,240,128,20,pokemon.markings)
    @sprites["pokemon"].setPokemonBitmap(pokemon)
    pbPositionPokemonSprite(@sprites["pokemon"],26,70)
  end

  def pbDropDownPartyTab
    begin
      Graphics.update
      Input.update
      @sprites["boxparty"].y-=16
      pbUpdateSpriteHash(@sprites)
    end until @sprites["boxparty"].y<=Graphics.height-352
  end

  def pbHidePartyTab
    begin
      Graphics.update
      Input.update
      @sprites["boxparty"].y+=16
      pbUpdateSpriteHash(@sprites)
    end until @sprites["boxparty"].y>=Graphics.height
  end

  def pbSetMosaic(selection)
    if !@screen.pbHeldPokemon
      if @boxForMosaic!=@storage.currentBox || @selectionForMosaic!=selection
        @sprites["pokemon"].mosaic=10
        @boxForMosaic=@storage.currentBox
        @selectionForMosaic=selection
      end
    end
  end

  def pbSelectBoxInternal(party)
    selection=@selection
    pbSetArrow(@sprites["arrow"],selection)
    pbUpdateOverlay(selection)
    pbSetMosaic(selection)
    loop do
      Graphics.update
      Input.update
      key=-1
      key=Input::DOWN if Input.repeat?(Input::DOWN)
      key=Input::RIGHT if Input.repeat?(Input::RIGHT)
      key=Input::LEFT if Input.repeat?(Input::LEFT)
      key=Input::UP if Input.repeat?(Input::UP)
      if key>=0
        pbPlayCursorSE()
        selection=pbChangeSelection(key,selection)
        pbSetArrow(@sprites["arrow"],selection)
        nextbox=-1
        if selection==-4
          nextbox=(@storage.currentBox==0) ? @storage.maxBoxes-1 : @storage.currentBox-1
          pbSwitchBoxToLeft(nextbox)
          @storage.currentBox=nextbox
          selection=-1
        elsif selection==-5
          nextbox=(@storage.currentBox==@storage.maxBoxes-1) ? 0 : @storage.currentBox+1
          pbSwitchBoxToRight(nextbox)
          @storage.currentBox=nextbox
          selection=-1
        end
        selection=-1 if selection==-4 || selection==-5
        pbUpdateOverlay(selection)
        pbSetMosaic(selection)
      end
      pbUpdateSpriteHash(@sprites)
      if Input.trigger?(Input::C)
        if selection>=0
          @selection=selection
          return [@storage.currentBox,selection]
        elsif selection==-1 # Box name 
          @selection=selection
          return [-4,-1]
        elsif selection==-2 # Party Pokémon 
          @selection=selection
          return [-2,-1]
        elsif selection==-3 # Close Box 
          @selection=selection
          return [-3,-1]
        end
      end
      if Input.trigger?(Input::B)
        @selection=selection
        return nil
      end
    end
  end

  def pbSelectBox(party)
    if @command==0 # Withdraw
      return pbSelectBoxInternal(party)
    else
      ret=nil
      loop do
        if !@choseFromParty
          ret=pbSelectBoxInternal(party)
        end
        if @choseFromParty || (ret && ret[0]==-2) # Party Pokémon
          if !@choseFromParty
            pbDropDownPartyTab
            @selection=0
          end
          ret=pbSelectPartyInternal(party,false)
          if ret<0
            pbHidePartyTab
            @selection=0
            @choseFromParty=false
          else
            @choseFromParty=true
            return [-1,ret]
          end
        else
          @choseFromParty=false
          return ret
        end
      end
    end
  end

  def pbHold(selected)
    if selected[0]==-1
      @sprites["boxparty"].grabPokemon(selected[1],@sprites["arrow"])
    else
      @sprites["box"].grabPokemon(selected[1],@sprites["arrow"])
    end
    while @sprites["arrow"].grabbing?
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
    end
  end

  def pbSwap(selected,heldpoke)
    heldpokesprite=@sprites["arrow"].heldPokemon
    boxpokesprite=nil
    if selected[0]==-1
      boxpokesprite=@sprites["boxparty"].getPokemon(selected[1])
    else
      boxpokesprite=@sprites["box"].getPokemon(selected[1])
    end
    if selected[0]==-1
      @sprites["boxparty"].setPokemon(selected[1],heldpokesprite)
    else
      @sprites["box"].setPokemon(selected[1],heldpokesprite)
    end
    @sprites["arrow"].setSprite(boxpokesprite)
    @sprites["pokemon"].mosaic=10
    @boxForMosaic=@storage.currentBox
    @selectionForMosaic=selected[1]
  end

  def pbPlace(selected,heldpoke)
    heldpokesprite=@sprites["arrow"].heldPokemon
    @sprites["arrow"].place
    while @sprites["arrow"].placing?
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@sprites)
    end
    if selected[0]==-1
      @sprites["boxparty"].setPokemon(selected[1],heldpokesprite)
    else
      @sprites["box"].setPokemon(selected[1],heldpokesprite)
    end
    @boxForMosaic=@storage.currentBox
    @selectionForMosaic=selected[1]
  end

  def pbChooseItem(bag)
    oldsprites=pbFadeOutAndHide(@sprites)
    scene=PokemonBag_Scene.new
    screen=PokemonBagScreen.new(scene,bag)
    ret=screen.pbGiveItemScreen
    pbFadeInAndShow(@sprites,oldsprites)
    return ret
  end

  def pbWithdraw(selected,heldpoke,partyindex)
    if !heldpoke
      pbHold(selected)
    end
    pbDropDownPartyTab
    pbPartySetArrow(@sprites["arrow"],partyindex)
    pbPlace([-1,partyindex],heldpoke)
    pbHidePartyTab
  end

  def pbSummary(selected,heldpoke)
    oldsprites=pbFadeOutAndHide(@sprites)
    scene=PokemonSummaryScene.new
    screen=PokemonSummary.new(scene)
    if heldpoke
      screen.pbStartScreen([heldpoke],0)
    elsif selected[0]==-1
      @selection=screen.pbStartScreen(@storage.party,selected[1])
      pbPartySetArrow(@sprites["arrow"],@selection)
      pbUpdateOverlay(@selection,@storage.party)
    else
      @selection=screen.pbStartScreen(@storage.boxes[selected[0]],selected[1])
      pbSetArrow(@sprites["arrow"],@selection)
      pbUpdateOverlay(@selection)
    end
    pbFadeInAndShow(@sprites,oldsprites)
  end

  def pbStore(selected,heldpoke,destbox,firstfree)
    if heldpoke
      if destbox==@storage.currentBox
        heldpokesprite=@sprites["arrow"].heldPokemon
        @sprites["box"].setPokemon(firstfree,heldpokesprite)
        @sprites["arrow"].setSprite(nil)
      else
        @sprites["arrow"].deleteSprite
      end
    else
      sprite=@sprites["boxparty"].getPokemon(selected[1])
      if destbox==@storage.currentBox
        @sprites["box"].setPokemon(firstfree,sprite)
        @sprites["boxparty"].setPokemon(selected[1],nil)
      else
        @sprites["boxparty"].deletePokemon(selected[1])
      end
    end
  end

  def drawMarkings(bitmap,x,y,width,height,markings)
    totaltext=""
    oldfontname=bitmap.font.name
    oldfontsize=bitmap.font.size
    oldfontcolor=bitmap.font.color
    bitmap.font.size=24
    bitmap.font.name="Arial"
    PokemonStorage::MARKINGCHARS.each{|item| totaltext+=item }
    totalsize=bitmap.text_size(totaltext)
    realX=x+(width/2)-(totalsize.width/2)
    realY=y+(height/2)-(totalsize.height/2)
    i=0
    PokemonStorage::MARKINGCHARS.each{|item|
       marked=(markings&(1<<i))!=0
       bitmap.font.color=(marked) ? Color.new(80,80,80) : Color.new(208,200,184)
       itemwidth=bitmap.text_size(item).width
       bitmap.draw_text(realX,realY,itemwidth+2,totalsize.height,item)
       realX+=itemwidth
       i+=1
    }
    bitmap.font.name=oldfontname
    bitmap.font.size=oldfontsize
    bitmap.font.color=oldfontcolor
  end

  def getMarkingCommands(markings)
    selectedtag="<c=505050>"
    deselectedtag="<c=D0C8B8>"
    commands=[]
    for i in 0...PokemonStorage::MARKINGCHARS.length
      commands.push( ((markings&(1<<i))==0 ? deselectedtag : selectedtag)+"<ac><fn=Arial>"+PokemonStorage::MARKINGCHARS[i])
    end
    commands.push(_INTL("OK"))
    commands.push(_INTL("Cancel"))   
    return commands
  end

  def pbMark(selected,heldpoke)
    ret=0
    msgwindow=Window_UnformattedTextPokemon.newWithSize("",180,0,Graphics.width-180,32)
    msgwindow.viewport=@viewport
    msgwindow.visible=true
    msgwindow.letterbyletter=false
    msgwindow.resizeHeightToFit(_INTL("Mark your Pokemon."),Graphics.width-180)
    msgwindow.text=_INTL("Mark your Pokemon.")
    pokemon=heldpoke
    if heldpoke
      pokemon=heldpoke
    elsif selected[0]==-1
      pokemon=@storage.party[selected[1]]
    else
      pokemon=@storage.boxes[selected[0]][selected[1]]
    end
    pbBottomRight(msgwindow)
    selectedtag="<c=505050>"
    deselectedtag="<c=D0C8B8>"
    commands=getMarkingCommands(pokemon.markings)
    cmdwindow=Window_AdvancedCommandPokemon.new(commands)
    cmdwindow.viewport=@viewport
    cmdwindow.visible=true
    cmdwindow.resizeToFit(cmdwindow.commands)
    cmdwindow.width=132
    cmdwindow.height=Graphics.height-msgwindow.height if cmdwindow.height>Graphics.height-msgwindow.height
    cmdwindow.update
    pbBottomRight(cmdwindow)
    markings=pokemon.markings
    cmdwindow.y-=msgwindow.height
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::B)
        break # cancel
      end
      if Input.trigger?(Input::C)
        if cmdwindow.index==commands.length-1
          break # cancel
        elsif cmdwindow.index==commands.length-2
          pokemon.markings=markings # OK
          break
        elsif cmdwindow.index>=0
          mask=(1<<cmdwindow.index)
          if (markings&mask)==0
            markings|=mask
          else
            markings&=~mask
          end
          commands=getMarkingCommands(markings)
          cmdwindow.commands=commands
        end
      end
      pbUpdateSpriteHash(@sprites)
      msgwindow.update
      cmdwindow.update
    end
    msgwindow.dispose
    cmdwindow.dispose
    Input.update
  end

  def pbRefresh
    @sprites["box"].refresh
    @sprites["boxparty"].refresh
  end

  def pbHardRefresh
    oldPartyY=@sprites["boxparty"].y
    @sprites["box"].dispose
    @sprites["boxparty"].dispose
    @sprites["box"]=PokemonBoxSprite.new(@storage,@storage.currentBox,@boxviewport)
    @sprites["boxparty"]=PokemonBoxPartySprite.new(@storage.party,@boxsidesviewport)
    @sprites["boxparty"].y=oldPartyY
  end

  def pbRelease(selected,heldpoke)
    box=selected[0]
    index=selected[1]
    if heldpoke
      sprite=@sprites["arrow"].heldPokemon
    elsif box==-1
      sprite=@sprites["boxparty"].getPokemon(index)
    else
      sprite=@sprites["box"].getPokemon(index)
    end
    if sprite
      sprite.release
      while sprite.releasing?
        Graphics.update
        sprite.update
        pbUpdateSpriteHash(@sprites)
      end
    end
  end

  def pbChooseBox(msg)
    commands=[]
    for i in 0...@storage.maxBoxes
      box=@storage[i]
      if box
        commands.push(_ISPRINTF("{1:s} ({2:d}/{3:d})",box.name,box.nitems,box.length))
      end
    end
    return pbShowCommands(msg,commands,@storage.currentBox)
  end

  def pbShowCommands(message,commands,index=0)
    ret=0
    msgwindow=Window_UnformattedTextPokemon.newWithSize("",180,0,Graphics.width-180,32)
    msgwindow.viewport=@viewport
    msgwindow.visible=true
    msgwindow.letterbyletter=false
    msgwindow.resizeHeightToFit(message,Graphics.width-180)
    msgwindow.text=message
    pbBottomRight(msgwindow)
    cmdwindow=Window_CommandPokemon.new(commands)
    cmdwindow.viewport=@viewport
    cmdwindow.visible=true
    cmdwindow.resizeToFit(cmdwindow.commands)
    cmdwindow.height=Graphics.height-msgwindow.height if cmdwindow.height>Graphics.height-msgwindow.height
    cmdwindow.update
    cmdwindow.index=index
    pbBottomRight(cmdwindow)
    cmdwindow.y-=msgwindow.height
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::B)
        ret=-1
        break
      end
      if Input.trigger?(Input::C)
        ret=cmdwindow.index
        break
      end
      pbUpdateSpriteHash(@sprites)
      msgwindow.update
      cmdwindow.update
    end
    msgwindow.dispose
    cmdwindow.dispose
    Input.update
    return ret
  end

  def pbDisplay(message)
    msgwindow=Window_UnformattedTextPokemon.newWithSize("",180,0,Graphics.width-180,32)
    msgwindow.viewport=@viewport
    msgwindow.visible=true
    msgwindow.letterbyletter=false
    msgwindow.resizeHeightToFit(message,Graphics.width-180)
    msgwindow.text=message
    pbBottomRight(msgwindow)
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::B)
        break
      end
      if Input.trigger?(Input::C)
        break
      end
      msgwindow.update
      pbUpdateSpriteHash(@sprites)
    end
    msgwindow.dispose
    Input.update
  end
end



################################################################################
# Regional Storage scripts
################################################################################
class RegionalStorage
  def initialize
    @storages=[]
    @lastmap=-1
    @rgnmap=-1
  end

  def getCurrentStorage
    if !$game_map
      raise _INTL("The player is not on a map, so the region could not be determined.")
    end
    if @lastmap!=$game_map.map_id
      @rgnmap=pbGetCurrentRegion # may access file IO, so caching result
      @lastmap=$game_map.map_id
    end
    if @rgnmap<0
      raise _INTL("The current map has no region set.  Please set the MapPosition metadata setting for this map.")
    end
    if !@storages[@rgnmap]
      @storages[@rgnmap]=PokemonStorage.new
    end
    return @storages[@rgnmap]
  end

  def boxes
    return getCurrentStorage.boxes
  end

  def party
    return getCurrentStorage.party
  end

  def currentBox
    return getCurrentStorage.currentBox
  end

  def currentBox=(value)
    getCurrentStorage.currentBox=value
  end

  def maxBoxes
    return getCurrentStorage.maxBoxes
  end

  def maxPokemon(box)
    return getCurrentStorage.maxPokemon(box)
  end

  def [](x,y=nil)
    getCurrentStorage[x,y]
  end

  def []=(x,y,value)
    getCurrentStorage[x,y]=value
  end

  def full?
    getCurrentStorage.full?
  end

  def pbFirstFreePos(box)
    getCurrentStorage.pbFirstFreePos(box)
  end

  def pbCopy(boxDst,indexDst,boxSrc,indexSrc)
    getCurrentStorage.pbCopy(boxDst,indexDst,boxSrc,indexSrc)
  end

  def pbMove(boxDst,indexDst,boxSrc,indexSrc)
    getCurrentStorage.pbCopy(boxDst,indexDst,boxSrc,indexSrc)
  end

  def pbMoveCaughtToParty(pkmn)
    getCurrentStorage.pbMoveCaughtToParty(pkmn) 
  end

  def pbMoveCaughtToBox(pkmn,box)
    getCurrentStorage.pbMoveCaughtToBox(pkmn,box)
  end

  def pbStoreCaught(pkmn)
    getCurrentStorage.pbStoreCaught(pkmn) 
  end

  def pbDelete(box,index)
    getCurrentStorage.pbDelete(pkmn)
  end
end



################################################################################
# PC menus
################################################################################
def Kernel.pbGetStorageCreator
  creator=pbStorageCreator
  creator=_INTL("Esteban") if !creator || creator==""
  return creator
end

def pbPCItemStorage
  loop do
    command=Kernel.pbShowCommandsWithHelp(nil,
       [_INTL("Withdraw Item"),
       _INTL("Deposit Item"),
       _INTL("Toss Item"),
       _INTL("Exit")],
       [_INTL("Take out items from the PC."),
       _INTL("Store items in the PC."),
       _INTL("Throw away items stored in the PC."),
       _INTL("Go back to the previous menu.")],-1
    )
    if command==0 # Withdraw Item
      if !$PokemonGlobal.pcItemStorage
        $PokemonGlobal.pcItemStorage=PCItemStorage.new
      end
      if $PokemonGlobal.pcItemStorage.empty?
        Kernel.pbMessage(_INTL("There are no items."))
      else
        pbFadeOutIn(99999){
           scene=WithdrawItemScene.new
           screen=PokemonBagScreen.new(scene,$PokemonBag)
           ret=screen.pbWithdrawItemScreen
        }
      end
    elsif command==1 # Deposit Item
      pbFadeOutIn(99999){
         scene=PokemonBag_Scene.new
         screen=PokemonBagScreen.new(scene,$PokemonBag)
         ret=screen.pbDepositItemScreen
      }
    elsif command==2 # Toss Item
      if !$PokemonGlobal.pcItemStorage
        $PokemonGlobal.pcItemStorage=PCItemStorage.new
      end
      if $PokemonGlobal.pcItemStorage.empty?
        Kernel.pbMessage(_INTL("There are no items."))
      else
        pbFadeOutIn(99999){
           scene=TossItemScene.new
           screen=PokemonBagScreen.new(scene,$PokemonBag)
           ret=screen.pbTossItemScreen
        }
      end
    else
      break
    end
  end
end

def pbPCMailbox
  if !$PokemonGlobal.mailbox || $PokemonGlobal.mailbox.length==0
    Kernel.pbMessage(_INTL("There's no Mail here."))
  else
    loop do
      commands=[]
      for mail in $PokemonGlobal.mailbox
        commands.push(mail.sender)
      end
      commands.push(_INTL("Cancel"))
      command=Kernel.pbShowCommands(nil,commands,-1)
      if command>=0 && command<$PokemonGlobal.mailbox.length
        mailIndex=command
        command=Kernel.pbMessage(_INTL("What do you want to do with {1}'s Mail?",
           $PokemonGlobal.mailbox[mailIndex].sender),[
           _INTL("Read"),
           _INTL("Move to Bag"),
           _INTL("Give"),
           _INTL("Cancel")
           ],-1)
        if command==0 # Read
          pbFadeOutIn(99999){
             pbDisplayMail($PokemonGlobal.mailbox[mailIndex])
          }
        elsif command==1 # Move to Bag
          if Kernel.pbConfirmMessage(_INTL("The message will be lost.  Is that OK?"))
            if $PokemonBag.pbStoreItem($PokemonGlobal.mailbox[mailIndex].item)
              Kernel.pbMessage(_INTL("The Mail was returned to the Bag with its message erased."))
              $PokemonGlobal.mailbox.delete_at(mailIndex)
            else
              Kernel.pbMessage(_INTL("The Bag is full."))
            end
          end
        elsif command==2 # Give
          pbFadeOutIn(99999){
             sscene=PokemonScreen_Scene.new
             sscreen=PokemonScreen.new(sscene,$Trainer.party)
             sscreen.pbPokemonGiveMailScreen(mailIndex)
          }
        end
      else
        break
      end
    end
  end
end

def pbTrainerPCMenu
  loop do
    command=Kernel.pbMessage(_INTL("What do you want to do?"),[
       _INTL("Item Storage"),
       _INTL("Mailbox"),
       _INTL("Turn Off")
       ],-1)
    if command==0
      pbPCItemStorage
    elsif command==1
      pbPCMailbox
    else
      break
    end
  end
end



module PokemonPCList
  @@pclist=[]

  def self.registerPC(pc)
    @@pclist.push(pc)
  end

  def self.getCommandList()
    commands=[]
    for pc in @@pclist
      if pc.shouldShow?
        commands.push(pc.name)
      end
    end
    commands.push(_INTL("Log Off"))
    return commands
  end

  def self.callCommand(cmd)
    if cmd<0 || cmd>=@@pclist.length
      return false
    end
    i=0
    for pc in @@pclist
      if pc.shouldShow?
        if i==cmd
           pc.access()
           return true
        end
        i+=1
      end
    end
    return false
  end
end



def pbTrainerPC
  Kernel.pbMessage(_INTL("\\se[computeropen]{1} booted up the PC.",$Trainer.name))
  pbTrainerPCMenu
  pbSEPlay("computerclose")
end



class TrainerPC
  def shouldShow?
    return true
  end

  def name
    return _INTL("{1}'s PC",$Trainer.name)
  end

  def access
    Kernel.pbMessage(_INTL("\\se[accesspc]Accessed {1}'s PC.",$Trainer.name))
    pbTrainerPCMenu
  end
end



class StorageSystemPC
  def shouldShow?
    return true
  end

  def name
    if $PokemonGlobal.seenStorageCreator
      return _INTL("{1}'s PC",Kernel.pbGetStorageCreator)
    else
      return _INTL("Someone's PC")
    end
  end

  def access
    Kernel.pbMessage(_INTL("\\se[accesspc]The Pokémon Storage System was opened."))
    loop do
      command=Kernel.pbShowCommandsWithHelp(nil,
         [_INTL("Withdraw Pokémon"),
         _INTL("Deposit Pokémon"),
         _INTL("Move Pokémon"),
         _INTL("See ya!")],
         [_INTL("Move Pokémon stored in Boxes to your party."),
         _INTL("Store Pokémon in your party in Boxes."),
         _INTL("Organize the Pokémon in Boxes and in your party."),
         _INTL("Return to the previous menu.")],-1
      )
      if command>=0 && command<3
        if command==0 && $PokemonStorage.party.length>=6
          Kernel.pbMessage(_INTL("Your party is full!"))
          next
        end
        count=0
        for p in $PokemonStorage.party
          count+=1 if p && !p.isEgg? && p.hp>0
        end
        if command==1 && count<=1
          Kernel.pbMessage(_INTL("Can't deposit the last Pokémon!"))
          next
        end
        pbFadeOutIn(99999){
           scene=PokemonStorageScene.new
           screen=PokemonStorageScreen.new(scene,$PokemonStorage)
           screen.pbStartScreen(command)
        }
      else
        break
      end
    end
  end
end



def pbPokeCenterPC
  Kernel.pbMessage(_INTL("\\se[computeropen]{1} booted up the PC.",$Trainer.name))
  loop do
    commands=PokemonPCList.getCommandList()
    command=Kernel.pbMessage(_INTL("Which PC should be accessed?"),
       commands,commands.length)
    if !PokemonPCList.callCommand(command)
      break
    end
  end
  pbSEPlay("computerclose")
end

PokemonPCList.registerPC(StorageSystemPC.new)
PokemonPCList.registerPC(TrainerPC.new)